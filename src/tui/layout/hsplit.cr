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
  # The split is either a fixed column count (#left_width) or a proportion
  # of the total width (#left_ratio) — the latter keeps both panes expanding
  # or shrinking together, relative to each other, across resizes, since
  # #layout re-derives #left_width from #left_ratio on every #composite.
  # Only one is active at a time; setting one clears the other.
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
    # height/#left_width or #left_ratio); mutate #left_width/#left_ratio
    # rather than these directly.
    getter left : Widget
    getter right : Widget

    # Applied to the divider line drawn by #render when #bordered? is true.
    property border_style : Style = Style.new(fg: TUI.color(:gray))

    # Whether to draw the vertical divider between panes — false to leave
    # the gap column blank, e.g. when each pane supplies its own visual
    # separation. Mirrors Window#bordered?.
    property? bordered : Bool

    @menu : KeyMenu
    @left_ratio : Float64? = nil

    def initialize(x : Int32, y : Int32, width : Int32, height : Int32,
                   @left : Widget, @right : Widget, left_width : Int32? = nil, left_ratio : Float64? = nil, @bordered : Bool = true)
      super(x, y, width, height)
      @left_width = 0
      @active = :left
      @menu = build_menu
      if left_ratio
        @left_ratio = left_ratio
      else
        @left_width = left_width || width // 2
      end
      layout
    end

    # Sizes and positions an HSplit to fill the screen below the status
    # bar row — see Window.full_screen for the same reasoning.
    # `left_width` defaults to an even split when neither it nor
    # `left_ratio` is given.
    def self.full_screen(screen : Screen, left : Widget, right : Widget, left_width : Int32? = nil, left_ratio : Float64? = nil, bordered : Bool = true) : HSplit
      new(1, 1, screen.cols, screen.rows - 1, left, right, left_width, left_ratio, bordered)
    end

    # Convenience wrapper for the common case of two Scrollables placed
    # side by side without a shared border — HSplit itself only accepts
    # full Widgets (see full_screen above), since each pane may be an
    # arbitrary composite widget, not just a bare Scrollable. Wraps each
    # Scrollable in its own borderless Window before delegating to
    # full_screen, replacing the pattern of hand-computing left_width and
    # building two matching Window.new calls.
    def self.full_screen_scrollables(screen : Screen, left : Scrollable, right : Scrollable, left_width : Int32? = nil, left_ratio : Float64? = nil) : HSplit
      lw = left_width || (left_ratio ? (left_ratio * screen.cols).round.to_i : screen.cols // 2)
      left_window = Window.new(1, 1, lw, screen.rows - 1, left, bordered: false)
      right_window = Window.new(1, 1, screen.cols - lw, screen.rows - 1, right, bordered: false)
      full_screen(screen, left_window, right_window, lw)
    end

    # Width in columns of the left pane, excluding the divider column. When
    # #left_ratio is set, this reflects the ratio's current column count as
    # of the last #layout, but is a derived value, not the source of truth.
    def left_width : Int32
      @left_width
    end

    # Sets a fixed column width for the left pane and switches out of ratio
    # mode (clears #left_ratio) — the two are mutually exclusive. Re-runs
    # #layout immediately so both panes' geometry stays consistent with the
    # new split.
    def left_width=(w : Int32) : Nil
      @left_ratio = nil
      @left_width = w
      layout
    end

    # Fraction (0.0-1.0) of total width the left pane occupies, re-derived
    # every #layout so both panes expand/shrink together, proportionally to
    # each other, across resizes — nil when in fixed-#left_width mode.
    def left_ratio : Float64?
      @left_ratio
    end

    # Switches to ratio mode: the left pane's width becomes `r * width`,
    # recomputed on every #layout (including resizes) instead of staying
    # pinned to an absolute column count. Re-runs #layout immediately.
    def left_ratio=(r : Float64) : Nil
      @left_ratio = r
      layout
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
      @buffer.vline(@left_width, 0, height, style: border_style) if bordered?
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
      if ratio = @left_ratio
        @left_width = (ratio * width).round.to_i.clamp(0, width)
      end

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
