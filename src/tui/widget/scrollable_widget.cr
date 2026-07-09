require "./widget"
require "./scrollable"
require "./scroll_control"

module TUI
  # Adapts a plain Widget to the Scrollable interface so it can be hosted
  # as a SplitWindow pane, which only accepts Scrollable (see
  # SplitWindow's shared border/scrollbar chrome, driven entirely off
  # Scrollable's content_size/render_content/header_rows). The wrapped
  # widget has no scrollable content of its own from SplitWindow's point
  # of view — content_size always matches whatever's visible, so the
  # pane's scrollbar shows full and never scrolls; the widget is free to
  # implement its own internal scrolling (as Window does for its
  # content) if it needs to.
  class ScrollableWidget
    include Scrollable

    property title : String

    # Tracks the last size #render_content was given, so #content_size
    # (called before render_content, while clamping the Scroller — see
    # SplitWindow#render) reports "exactly fills the viewport" for
    # whatever viewport SplitWindow measured last frame — 0 the very
    # first frame, before any render_content call has run, which
    # Scroller#clamp treats as a no-op.
    @visible_size : Int32 = 0

    def initialize(@widget : Widget, @title : String = "")
    end

    def content_size : Int32
      @visible_size
    end

    def render_content(buffer : Buffer, scroll : ScrollControl) : Nil
      @visible_size = buffer.height
      @widget.x = 0
      @widget.y = 0
      @widget.width = buffer.width
      @widget.height = buffer.height
      @widget.focus_if(focused?)
      @widget.render_to(buffer)
    end

    def handle_key(ev : KeyEvent, scroll : ScrollControl) : Bool
      @widget.handle_key(ev)
    end

    def handle_click(local_row : Int32, local_col : Int32, scroll : ScrollControl) : Bool
      @widget.handle_key(KeyEvent.new(Key::MouseClick, row: @widget.y + local_row, col: @widget.x + local_col))
    end

    def status_hint : String
      @widget.status_hint
    end
  end
end
