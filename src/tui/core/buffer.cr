require "./term"

module TUI
  # One character cell: the glyph itself plus the ANSI SGR escape sequence
  # (`style`) that should be emitted before it. Screen#flush diffs on the
  # (char, style) pair to decide which cells actually changed since the
  # last frame.
  record BufferCell, char : String = " ", style : String = ""

  # A widget-local grid of cells. Widgets draw into their own Buffer using
  # coordinates relative to their own top-left (0, 0) — never absolute
  # terminal coordinates. The compositor (Screen) blits each widget's
  # Buffer onto the real screen at the widget's x/y offset.
  class Buffer
    # Fixed size in cells, set at construction. A widget wanting a
    # different size builds a new Buffer (see Widget#composite) rather
    # than resizing this one in place.
    getter width : Int32
    getter height : Int32

    def initialize(@width : Int32, @height : Int32)
      @cells = Array(BufferCell).new(@width * @height, BufferCell.new)
    end

    # Write a string starting at local (row, col), 0-indexed. ANSI escape
    # sequences in `s` are tracked as the running style and attached to each
    # subsequent plain character's cell, rather than being written as their
    # own cells — this lets the compositor diff on (char, style) per cell.
    def set(row : Int32, col : Int32, s : String) : Nil
      return if row < 0 || row >= @height
      style = ""
      plain_col = col
      s.scan(/(\e\[[0-9;]*m)|(.)/m) do |match|
        if esc = match[1]?
          style = esc == "\e[0m" ? "" : style + esc
        elsif ch = match[2]?
          if plain_col >= 0 && plain_col < @width
            @cells[row * @width + plain_col] = BufferCell.new(ch, style)
          end
          plain_col += 1
        end
      end
    end

    def set_cell(row : Int32, col : Int32, cell : BufferCell) : Nil
      return if row < 0 || row >= @height || col < 0 || col >= @width
      @cells[row * @width + col] = cell
    end

    def clear : Nil
      @cells.fill(BufferCell.new)
    end

    def cell(row : Int32, col : Int32) : BufferCell
      @cells[row * @width + col]
    end

    # Draw a box with an optional title in the top border, in local coords.
    # `style` applies only to the border glyphs themselves — a title's own
    # text is drawn plain here (its emphasis, if any, is the widget's own
    # concern, e.g. ListView#title_style) so it doesn't inherit the
    # border's color.
    def box(y : Int32, x : Int32, h : Int32, w : Int32, title : String = "", style : Style = Style.new) : Nil
      return if h < 1 || w < 1
      inner_w = [w - 2, 0].max
      corner = ->(s : String) { Term.apply(style, s) }
      fill = Term.apply(style, Term::HL)
      top_fill = if title.empty?
                   fill * inner_w
                 else
                   t = " #{title} "
                   pad = [inner_w - Term.visible_size(t), 0].max
                   t + fill * pad
                 end
      set(y, x, "#{corner.call(Term::TL)}#{top_fill}#{corner.call(Term::TR)}")

      (1..h - 2).each do |row_offset|
        set(y + row_offset, x, corner.call(Term::VL))
        set(y + row_offset, x + w - 1, corner.call(Term::VL))
      end

      set(y + h - 1, x, "#{corner.call(Term::BL)}#{fill * inner_w}#{corner.call(Term::BR)}")
    end

    # Draw a box like #box, but with a T-junction character injected into
    # the top and bottom border rows at local column `divider_at` — used
    # by SplitWindow to merge its internal pane divider into the outer
    # border.
    def box_with_divider(y : Int32, x : Int32, h : Int32, w : Int32, divider_at : Int32, title : String = "", style : Style = Style.new) : Nil
      box(y, x, h, w, title, style)
      set(y, x + divider_at, Term.apply(style, Term::TJ))
      set(y + h - 1, x + divider_at, Term.apply(style, Term::BJ))
    end

    # Draws a vertical scrollbar in the right border column of a box.
    # `fraction` is the 0.0 (top) to 1.0 (bottom) position of the viewport,
    # `visible`/`total` size the thumb proportionally. `fraction` nil means
    # no scrollbar (content fits entirely, nothing to indicate).
    def scrollbar(y : Int32, x : Int32, h : Int32, fraction : Float64?, visible : Int32 = 0, total : Int32 = 0, style : Style = Style.new) : Nil
      return unless fraction
      track_h = h - 2
      return if track_h <= 0

      ratio = total > 0 ? visible / total.to_f : 1.0
      thumb_h = [1, (track_h * ratio).round.to_i].max
      thumb_h = [thumb_h, track_h].min
      max_thumb_start = track_h - thumb_h
      thumb_start = (fraction * max_thumb_start).round.to_i

      (0...track_h).each do |row|
        # Right-half block for the thumb (matching lazygit's scrollbar
        # style) — reads as an accent on the border rather than a solid
        # block replacing it.
        ch = (row >= thumb_start && row < thumb_start + thumb_h) ? "▐" : Term::VL
        set(y + 1 + row, x, Term.apply(style, ch))
      end
    end

    # Draw a horizontal separator spanning w columns at (y, x).
    # left_join / right_join use ├ / ┤ instead of └ / ┘.
    def hline(y : Int32, x : Int32, w : Int32, left_join : Bool = false, right_join : Bool = false, style : Style = Style.new) : Nil
      return if w < 1
      left = left_join ? Term::LJ : Term::BL
      right = right_join ? Term::RJ : Term::BR
      set(y, x, Term.apply(style, "#{left}#{Term::HL * [w - 2, 0].max}#{right}"))
    end

    # Draw a vertical line of h rows starting at (y, x), local coords.
    def vline(x : Int32, y : Int32, h : Int32, style : Style = Style.new) : Nil
      h.times { |row| set(y + row, x, Term.apply(style, Term::VL)) }
    end
  end
end
