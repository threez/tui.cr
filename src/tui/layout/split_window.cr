require "../widget/widget"
require "../widget/scroller"
require "../widget/scrollable"
require "../widget/scroll_control"
require "../widget/key_menu"

module TUI
  # One bordered box hosting two Scrollable content areas side by side,
  # each with its own independent scroll position. The left pane's right
  # edge is the internal divider column, which doubles as its scrollbar
  # track (Buffer#scrollbar accepts an arbitrary column, so this needs no
  # new drawing primitive); the right pane's scrollbar renders on the
  # outer right border column exactly as Window's single pane does.
  class SplitWindow < Widget
    # Whether to draw the box border/scrollbar chrome — same convention
    # as Window#bordered?.
    property? bordered : Bool

    # Applied to the box border and internal pane divider drawn by
    # #render.
    property border_style : Style = Style.new(fg: TUI.color(:gray))

    @scrollbar_style : Style? = nil

    # Applied to both panes' scrollbar track and thumb drawn by #render —
    # defaults to whatever #border_style currently is, so scrollbar and
    # border stay visually matched unless a caller explicitly sets this
    # to something else. Resolved fresh on every read (not captured
    # once), so an unset scrollbar_style keeps tracking border_style
    # even if border_style is changed later.
    def scrollbar_style : Style
      @scrollbar_style || border_style
    end

    def scrollbar_style=(style : Style) : Nil
      @scrollbar_style = style
    end

    @menu : KeyMenu

    def initialize(x : Int32, y : Int32, width : Int32, height : Int32,
                   @left : Scrollable, @right : Scrollable, left_width : Int32,
                   @bordered : Bool = true)
      super(x, y, width, height)
      @left_width = left_width
      @left_scroller = Scroller.new
      @right_scroller = Scroller.new
      @active = :left
      @menu = build_menu
    end

    # Sizes and positions a SplitWindow to fill the screen below the
    # status bar row — see Window.full_screen for the same reasoning.
    # `left_width` defaults to an even split.
    def self.full_screen(screen : Screen, left : Scrollable, right : Scrollable,
                         left_width : Int32? = nil, bordered : Bool = true) : SplitWindow
      new(1, 1, screen.cols, screen.rows - 1, left, right, left_width || screen.cols // 2, bordered)
    end

    # Width in columns of the left pane's content area, excluding the
    # divider column. Adjustable at runtime (e.g. a draggable-divider
    # feature) independent of #initialize's initial split.
    def left_width=(w : Int32) : Nil
      @left_width = w
    end

    def left_width : Int32
      @left_width
    end

    # Resets which pane is active back to the left one — for a host app
    # that reuses the same SplitWindow instance across appearances (e.g.
    # showing/hiding it based on runtime state) and wants a consistent
    # starting focus each time it reappears, rather than carrying over
    # whatever pane was last active before it was hidden.
    def focus_left : Nil
      @active = :left
    end

    def render : Nil
      left_total = @left.content_size
      right_total = @right.content_size
      left_visible = scrollable_visible(@left)
      right_visible = scrollable_visible(@right)
      @left_scroller.clamp(left_total, left_visible)
      @right_scroller.clamp(right_total, right_visible)

      @left.focus_if(@active == :left)
      @right.focus_if(@active == :right)

      if bordered?
        @buffer.box_with_divider(0, 0, height, width, divider_at: @left_width + 1, title: @left.title, style: border_style)
        @buffer.vline(@left_width + 1, 1, height - 2, style: border_style)
        @buffer.scrollbar(0, @left_width + 1, height, @left_scroller.fraction(left_total, left_visible), visible: left_visible, total: left_total, style: scrollbar_style)
        @buffer.scrollbar(0, width - 1, height, @right_scroller.fraction(right_total, right_visible), visible: right_visible, total: right_total, style: scrollbar_style)
      else
        @buffer.vline(@left_width, 0, height, style: border_style)
      end

      left_inner = Buffer.new(@left_width, inner_height)
      @left.render_content(left_inner, ScrollControl.new(@left_scroller, left_visible))
      blit(left_inner, row_off: inset, col_off: inset)

      right_w = inner_width - @left_width - 1
      right_inner = Buffer.new(right_w, inner_height)
      @right.render_content(right_inner, ScrollControl.new(@right_scroller, right_visible))
      blit(right_inner, row_off: inset, col_off: inset + @left_width + 1)
    end

    def handle_key(ev : KeyEvent) : Bool
      return true if @menu.dispatch(ev)
      return route_click(ev) if ev.key == Key::MouseClick

      scroll = ScrollControl.new(active_scroller, scrollable_visible(active_pane))
      active_pane.handle_key(ev, scroll)
    end

    def status_hint : String
      @menu.hint + "  " + active_pane.status_hint
    end

    private def build_menu : KeyMenu
      menu = KeyMenu.new
      menu.bind(Key::Tab, "Tab:switch pane") { @active = @active == :left ? :right : :left }
      menu
    end

    private def active_pane : Scrollable
      @active == :left ? @left : @right
    end

    private def active_scroller : Scroller
      @active == :left ? @left_scroller : @right_scroller
    end

    private def route_click(ev : KeyEvent) : Bool
      loc = local(ev.row.as(Int32), ev.col.as(Int32))
      cr, cc = loc[:row] - inset, loc[:col] - inset
      return true if cr < 0 || cr >= inner_height || cc < 0 || cc >= inner_width

      case
      when cc == @left_width
        true # click landed exactly on the divider — consume, route to neither pane
      when cc < @left_width
        @active = :left
        @left.handle_click(cr, cc, ScrollControl.new(@left_scroller, scrollable_visible(@left)))
      else
        @active = :right
        @right.handle_click(cr, cc - @left_width - 1, ScrollControl.new(@right_scroller, scrollable_visible(@right)))
      end
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

    # The row count actually available for `pane`'s data rows — see
    # Window#scrollable_visible for the same reasoning. Taken per-pane
    # (not once for both) since the left and right Scrollable may
    # reserve different header row counts.
    private def scrollable_visible(pane : Scrollable) : Int32
      [inner_height - pane.header_rows, 0].max
    end

    private def blit(inner : Buffer, row_off : Int32, col_off : Int32) : Nil
      inner.height.times do |row|
        inner.width.times do |col|
          @buffer.set_cell(row + row_off, col + col_off, inner.cell(row, col))
        end
      end
    end
  end
end
