require "../widget/widget"
require "../widget/window"
require "../widget/scrollable"
require "../widget/key_menu"

module TUI
  # Positions two widgets side by side with a vertical divider between them,
  # replacing the pattern of hand-computing a split width and drawing the
  # divider with manual absolute-coordinate calls. Owns only the children's
  # geometry and the divider — each child still renders itself.
  #
  # `Tab` toggles which pane is active and routes keys to it — the same
  # convention SplitWindow uses for its two Scrollables, generalized here
  # to two full Widgets. Each child's `focus_if` is driven from the active
  # pane each render, so a widget like TableView can style its own cursor
  # row accordingly, exactly as it would hosted standalone or in
  # SplitWindow.
  class HSplit < Widget
    # The two hosted panes. Read-only from outside — HSplit itself owns
    # their geometry (see #layout, driven from HSplit's own x/y/width/
    # height/#left_width); mutate #left_width rather than these directly.
    getter left : Widget
    getter right : Widget

    # Applied to the divider line drawn by #render.
    property border_style : Style = Style.new(fg: TUI.color(:gray))

    @menu : KeyMenu

    def initialize(x : Int32, y : Int32, width : Int32, height : Int32,
                   @left : Widget, @right : Widget, left_width : Int32)
      super(x, y, width, height)
      @left_width = left_width
      @active = :left
      @menu = build_menu
      layout
    end

    # Sizes and positions an HSplit to fill the screen below the status
    # bar row — see Window.full_screen for the same reasoning.
    # `left_width` defaults to an even split.
    def self.full_screen(screen : Screen, left : Widget, right : Widget, left_width : Int32? = nil) : HSplit
      new(1, 1, screen.cols, screen.rows - 1, left, right, left_width || screen.cols // 2)
    end

    # Convenience wrapper for the common case of two Scrollables placed
    # side by side without a shared border — HSplit itself only accepts
    # full Widgets (see full_screen above), since each pane may be an
    # arbitrary composite widget, not just a bare Scrollable. Wraps each
    # Scrollable in its own borderless Window before delegating to
    # full_screen, replacing the pattern of hand-computing left_width and
    # building two matching Window.new calls.
    def self.full_screen_scrollables(screen : Screen, left : Scrollable, right : Scrollable, left_width : Int32? = nil) : HSplit
      lw = left_width || screen.cols // 2
      left_window = Window.new(1, 1, lw, screen.rows - 1, left, bordered: false)
      right_window = Window.new(1, 1, screen.cols - lw, screen.rows - 1, right, bordered: false)
      full_screen(screen, left_window, right_window, lw)
    end

    # Width in columns of the left pane, excluding the divider column.
    # Setting it re-runs #layout immediately so both panes' geometry
    # stays consistent with the new split.
    def left_width=(w : Int32) : Nil
      @left_width = w
      layout
    end

    def left_width : Int32
      @left_width
    end

    # Resets which pane is active back to the left one — for a host app
    # that reuses the same HSplit instance across appearances and wants a
    # consistent starting focus each time it reappears, rather than
    # carrying over whatever pane was last active before it was hidden.
    # Mirrors SplitWindow#focus_left.
    def focus_left : Nil
      @active = :left
    end

    # Children are separate widgets with their own buffers — composite them
    # directly onto the screen rather than drawing them into HSplit's own
    # buffer, then draw just the divider into HSplit's buffer as usual.
    #
    # Order matters: `super` (Widget#composite) blits HSplit's OWN buffer —
    # blank except for the divider column — over its entire bounding box.
    # If that ran after the children, it would wipe out everything they
    # just drew except the one divider column. Draw the divider first, so
    # each child's later blit wins for its own region and only the actual
    # divider column (never touched by either child) is left showing it.
    def composite(screen : Screen) : Nil
      layout
      @left.focus_if(@active == :left)
      @right.focus_if(@active == :right)
      super
      @left.composite(screen)
      @right.composite(screen)
    end

    def render : Nil
      @buffer.vline(@left_width, 0, height, style: border_style)
    end

    def handle_key(ev : KeyEvent) : Bool
      return true if @menu.dispatch(ev)
      active_pane.handle_key(ev)
    end

    def status_hint : String
      @menu.hint + "  " + active_pane.status_hint
    end

    private def build_menu : KeyMenu
      menu = KeyMenu.new
      menu.bind(Key::Tab, "Tab:switch pane") { @active = @active == :left ? :right : :left }
      menu
    end

    private def active_pane : Widget
      @active == :left ? @left : @right
    end

    private def layout : Nil
      @left.x = x
      @left.y = y
      @left.width = @left_width
      @left.height = height

      @right.x = x + @left_width + 1
      @right.y = y
      @right.width = [width - @left_width - 1, 0].max
      @right.height = height
    end
  end
end
