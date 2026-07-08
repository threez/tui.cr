require "./term"
require "./buffer"

module TUI
  # A rectangle, in the same 1-based coordinate convention as Widget#x/
  # #y, that Screen#with_clip bounds #blit writes to. Exists so a
  # container of independently-compositing children (see Grid,
  # src/tui/layout/grid.cr) can bound where its children are allowed to
  # draw without needing to intercept or redirect their #composite calls
  # — every Widget#composite ever reaches the real screen through
  # exactly one call, Screen#blit, so clipping there is sufficient no
  # matter how deep the widget tree gets.
  record ClipRect, row : Int32, col : Int32, height : Int32, width : Int32 do
    # Narrows `self` to the overlap with `other` — used by #with_clip so
    # a nested clip can only ever shrink the bound in effect, never
    # widen past an outer container's own clip.
    def intersect(other : ClipRect) : ClipRect
      row1 = [row, other.row].max
      col1 = [col, other.col].max
      row2 = [row + height, other.row + other.height].min
      col2 = [col + width, other.col + other.width].min
      ClipRect.new(row: row1, col: col1, height: [row2 - row1, 0].max, width: [col2 - col1, 0].max)
    end
  end

  class Screen
    # Current terminal size in character cells, refreshed by #refresh_size
    # on resize. 0-based row/col math elsewhere in this class treats these
    # as the exclusive upper bound.
    getter rows : Int32
    getter cols : Int32

    # Applied to the whole row drawn by #status_bar.
    property status_bar_style : Style = Style.new(reverse: true)

    @clip : ClipRect? = nil

    def initialize
      size = Term.size
      @rows = size[:rows]
      @cols = size[:cols]
      @front = Buffer.new(@cols, @rows)
      @back = Buffer.new(@cols, @rows)
    end

    # Bounds every #blit inside `block` to `rect`, intersected with
    # whatever clip is already active (so a clip can only narrow, never
    # widen, no matter how many containers are nested). Always restores
    # the previous clip afterward, even if `block` raises, so a
    # container's own clip can never leak past its own #composite call.
    # Default (`@clip` nil) is "no bound" — existing callers that never
    # call #with_clip see zero behavior change.
    def with_clip(rect : ClipRect, & : -> Nil) : Nil
      previous = @clip
      @clip = previous ? previous.intersect(rect) : rect
      yield
    ensure
      @clip = previous
    end

    def refresh_size : Nil
      size = Term.size
      @rows = size[:rows]
      @cols = size[:cols]
      # A shrinking terminal can leave stale content outside the new,
      # smaller grid that the cell-diff in `flush` will never visit (it
      # only iterates the current rows/cols). Clear the real terminal once
      # here; the fresh buffers below then force a correct full repaint on
      # the next flush. This is a one-time cost on resize, not per-frame,
      # so it doesn't reintroduce flicker.
      print Term.clear
      STDOUT.flush
      @front = Buffer.new(@cols, @rows)
      @back = Buffer.new(@cols, @rows)
    end

    # Read back a cell from the back buffer — the one composited widgets
    # have just blitted into, before the next #flush swaps it to front.
    # Exists for specs to assert on composited output; app code should
    # never need to read cells back out of the screen it just drew.
    def cell(row : Int32, col : Int32) : BufferCell
      @back.cell(row, col)
    end

    # Composite a widget's local buffer onto the back buffer at (x, y).
    # x/y are 1-based terminal coordinates (matching Widget#x/#y convention).
    # Cells landing outside the currently active #with_clip rect (if any)
    # are silently dropped, same "out of bounds is a no-op, not an
    # error" convention Buffer#set_cell already uses for the screen's own
    # edges.
    def blit(x : Int32, y : Int32, buffer : Buffer) : Nil
      buffer.height.times do |row|
        buffer.width.times do |col|
          abs_row, abs_col = y - 1 + row, x - 1 + col
          next unless clip_allows?(abs_row, abs_col)
          @back.set_cell(abs_row, abs_col, buffer.cell(row, col))
        end
      end
    end

    # Write directly into the back buffer at absolute terminal coordinates.
    # For App-level drawing that isn't owned by any single widget (status
    # bar, dividers between panes).
    def at(row : Int32, col : Int32, s : String) : Nil
      @back.set(row - 1, col - 1, s)
    end

    # Draw a vertical line at absolute terminal coordinates, e.g. a divider
    # between two side-by-side widget panes.
    def vline(x : Int32, y : Int32, h : Int32) : Nil
      h.times { |row| at(y + row, x, Term::VL) }
    end

    # Status bar: fill entire row with reverse-video text (absolute coords).
    def status_bar(row : Int32, text : String) : Nil
      fitted = Term.fit(text, @cols)
      at(row, 1, Term.apply(status_bar_style, fitted))
    end

    # Diff @back against @front, emit only changed cells, then swap.
    #
    # The real terminal cursor stays hidden across frames — apps draw their
    # own selection highlight (reverse-video rows, block glyphs for text
    # input) rather than relying on the terminal's cursor to convey
    # position. A caller that needs the native cursor visible (e.g. a text
    # field mid-edit) should show it and move it itself after calling
    # flush, then hide it again before the next flush.
    def flush : Nil
      frame = String::Builder.new
      @rows.times do |row|
        # Style never carries across a row boundary: a terminal (or a
        # multiplexer like tmux re-serializing its own grid) can otherwise
        # paint a skipped/untouched cell — e.g. a border column past the
        # last styled cell of a highlighted row — using whatever SGR was
        # last active, which shows up as the row highlight bleeding onto
        # the frame border or lagging a row behind on scroll.
        last_style = ""
        @cols.times do |col|
          old_cell = @front.cell(row, col)
          new_cell = @back.cell(row, col)
          next if old_cell == new_cell

          frame << Term.move(row + 1, col + 1)
          if new_cell.style != last_style
            frame << Term::RESET
            frame << new_cell.style unless new_cell.style.empty?
            last_style = new_cell.style
          end
          frame << new_cell.char
        end
        frame << Term::RESET unless last_style.empty?
      end
      STDOUT.print frame.to_s
      STDOUT.flush

      @front, @back = @back, @front
      @back.clear
    end

    # `abs_row`/`abs_col` are 0-based (matching @back's own #set_cell
    # convention, as used by #blit above); @clip is 1-based (matching
    # Widget#x/#y, as used by every ClipRect built from a widget's own
    # geometry) — the -1 below is the same convention translation #blit
    # itself already does for x/y.
    private def clip_allows?(abs_row : Int32, abs_col : Int32) : Bool
      return true unless c = @clip
      abs_row >= c.row - 1 && abs_row < c.row - 1 + c.height &&
        abs_col >= c.col - 1 && abs_col < c.col - 1 + c.width
    end
  end
end
