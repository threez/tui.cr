require "./term"
require "./buffer"

module TUI
  class Screen
    # Current terminal size in character cells, refreshed by #refresh_size
    # on resize. 0-based row/col math elsewhere in this class treats these
    # as the exclusive upper bound.
    getter rows : Int32
    getter cols : Int32

    # Applied to the whole row drawn by #status_bar.
    property status_bar_style : Style = Style.new(reverse: true)

    def initialize
      size = Term.size
      @rows = size[:rows]
      @cols = size[:cols]
      @front = Buffer.new(@cols, @rows)
      @back = Buffer.new(@cols, @rows)
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
    def blit(x : Int32, y : Int32, buffer : Buffer) : Nil
      buffer.height.times do |row|
        buffer.width.times do |col|
          @back.set_cell(y - 1 + row, x - 1 + col, buffer.cell(row, col))
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
  end
end
