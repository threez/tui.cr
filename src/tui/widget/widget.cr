require "../core/screen"
require "../core/buffer"
require "../core/keys"

module TUI
  abstract class Widget
    # 1-based absolute terminal coordinates and size of this widget within
    # the compositor (see #composite/Screen#blit) — never touched by the
    # widget's own #render, which always draws in its own local (0, 0)
    # space. `focused?` gates whether this widget's #handle_key should be
    # given a chance to consume the current event; toggle it via #focus_if.
    property x : Int32
    property y : Int32
    property width : Int32
    property height : Int32
    property? focused : Bool

    def initialize(@x : Int32, @y : Int32, @width : Int32, @height : Int32)
      @focused = false
      @buffer = Buffer.new(@width, @height)
    end

    # The recommended way to manage focus when multiple widgets are visible
    # at once: recompute it every frame from whatever state determines which
    # widget is active (e.g. `table_list.focus_if(nav.current.is_a?(NavTableList))`)
    # rather than mutating `focused=` incrementally at scattered call sites.
    def focus_if(condition : Bool) : Nil
      @focused = condition
    end

    # Draw into @buffer using LOCAL coordinates (0, 0 = this widget's own
    # top-left). Widgets never need to know their own x/y offset to draw
    # themselves — that arithmetic is handled entirely by `composite`.
    abstract def render : Nil

    # Returns true if the key was consumed.
    abstract def handle_key(ev : KeyEvent) : Bool

    # Plain text describing the actions available in the widget's current
    # state. Rendered by the App in the global status bar at the bottom
    # of the screen — widgets must NOT draw their own hint lines.
    abstract def status_hint : String

    # Called by the compositor (App) once per frame instead of `render`.
    # Owns the buffer lifecycle: resizes/clears it, invokes the subclass's
    # `render`, then blits the result onto the screen at (x, y).
    def composite(screen : Screen) : Nil
      if @buffer.width != width || @buffer.height != height
        @buffer = Buffer.new(width, height)
      else
        @buffer.clear
      end
      render
      screen.blit(x, y, @buffer)
    end

    # Translate a LOCAL (row, col) offset — as used by `render`'s own
    # coordinate space, e.g. Form#cursor_offset — into absolute
    # 1-based terminal coordinates suitable for Term.move. Mirrors the
    # arithmetic `composite` already performs internally via Screen#blit.
    def absolute(row : Int32, col : Int32) : {row: Int32, col: Int32}
      {row: y + row, col: x + col}
    end

    # Inverse of #absolute: translate an ABSOLUTE 1-based terminal
    # coordinate (e.g. a KeyEvent's mouse row/col) into this widget's
    # LOCAL coordinate space. Result may fall outside [0, width)/[0,
    # height) if the point is outside this widget's bounds — callers
    # should bounds-check.
    def local(row : Int32, col : Int32) : {row: Int32, col: Int32}
      {row: row - y, col: col - x}
    end
  end
end
