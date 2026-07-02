require "./screen"
require "./keys"

module TUI
  abstract class Widget
    property x : Int32
    property y : Int32
    property width : Int32
    property height : Int32
    property? focused : Bool

    def initialize(@x : Int32, @y : Int32, @width : Int32, @height : Int32)
      @focused = false
    end

    abstract def render(screen : Screen) : Nil

    # Returns true if the key was consumed.
    abstract def handle_key(ev : KeyEvent) : Bool

    # Plain text describing the actions available in the widget's current
    # state. Rendered by the App in the global status bar at the bottom
    # of the screen — widgets must NOT draw their own hint lines.
    abstract def status_hint : String
  end
end
