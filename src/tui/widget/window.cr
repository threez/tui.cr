require "./widget"
require "./scroller"
require "./scrollable"
require "./scroll_control"

module TUI
  # Owns the border, scrollbar, and scroll position for a hosted
  # Scrollable — the piece that lets content be embedded either
  # standalone (bordered) or side-by-side in a layout container like
  # HSplit (borderless, no shared chrome of its own).
  class Window < Widget
    # Whether to draw the box border/scrollbar chrome around #content —
    # false for panes embedded borderless inside a layout container like
    # HSplit, which supplies its own shared chrome instead.
    property? bordered : Bool

    # Applied to the box border drawn by #render when #bordered? is true.
    property border_style : Style = Style.new(fg: TUI.color(:gray))

    @scrollbar_style : Style? = nil

    # Applied to the scrollbar track and thumb drawn by #render when
    # #bordered? is true — defaults to whatever #border_style currently
    # is, so scrollbar and border stay visually matched unless a caller
    # explicitly sets this to something else. Resolved fresh on every
    # read (not captured once), so an unset scrollbar_style keeps
    # tracking border_style even if border_style is changed later.
    def scrollbar_style : Style
      @scrollbar_style || border_style
    end

    def scrollbar_style=(style : Style) : Nil
      @scrollbar_style = style
    end

    def initialize(x : Int32, y : Int32, width : Int32, height : Int32,
                   @content : Scrollable, @bordered : Bool = true)
      super(x, y, width, height)
      @scroller = Scroller.new
    end

    # Sizes and positions a Window to fill the screen below the status
    # bar row — the same geometry Runtime#push resizes any full-screen
    # page widget to, spelled once here instead of every call site
    # re-deriving `1, 1, screen.cols, screen.rows - 1` by hand.
    def self.full_screen(screen : Screen, content : Scrollable, bordered : Bool = true) : Window
      new(1, 1, screen.cols, screen.rows - 1, content, bordered)
    end

    # Resets scroll position. Content itself has no Scroller to reset —
    # callers that mutate content directly (e.g. loading new data into a
    # DetailView outside the normal handle_key flow) call this afterward.
    def reset_scroll : Nil
      @scroller.reset
    end

    def render : Nil
      total = @content.content_size
      visible = scrollable_visible
      @scroller.clamp(total, visible)

      if bordered?
        @buffer.box(0, 0, height, width, @content.title, border_style)
        @buffer.scrollbar(0, width - 1, height, @scroller.fraction(total, visible), visible: visible, total: total, style: scrollbar_style)
      end

      inner = Buffer.new(inner_width, inner_height)
      @content.render_content(inner, ScrollControl.new(@scroller, visible))
      blit_inner(inner)
    end

    def handle_key(ev : KeyEvent) : Bool
      scroll = ScrollControl.new(@scroller, scrollable_visible)
      if ev.key == Key::MouseClick
        loc = local(ev.row.as(Int32), ev.col.as(Int32))
        cr, cc = loc[:row] - inset, loc[:col] - inset
        return true if cr < 0 || cc < 0 || cr >= inner_height || cc >= inner_width
        @content.handle_click(cr, cc, scroll)
      else
        @content.handle_key(ev, scroll)
      end
    end

    def status_hint : String
      @content.status_hint
    end

    private def inset : Int32
      bordered? ? 1 : 0
    end

    private def inner_width : Int32
      width - 2 * inset
    end

    private def inner_height : Int32
      height - 2 * inset
    end

    # The row count actually available for #content's data rows — the
    # inner buffer size minus whatever #content itself reserves for a
    # header (Scrollable#header_rows) — so the Scroller/ScrollControl
    # this hands to #content can never let the cursor or scroll offset
    # advance past what #render_content actually has room to draw.
    private def scrollable_visible : Int32
      [inner_height - @content.header_rows, 0].max
    end

    private def blit_inner(inner : Buffer) : Nil
      inner.height.times do |row|
        inner.width.times do |col|
          @buffer.set_cell(row + inset, col + inset, inner.cell(row, col))
        end
      end
    end
  end
end
