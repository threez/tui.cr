require "../widget/widget"

module TUI
  # A widget that can report the value currently under its cursor, so it can
  # be wrapped as a picker without any dedicated "picker mode" of its own.
  module Pickable
    abstract def selected_value : String?
  end

  # Wraps any Pickable widget as a modal value-picker. Does not modify the
  # wrapped widget — filters its key input externally: Enter reports the
  # selection, Esc cancels, listed chars are swallowed (e.g. to suppress
  # mutating actions like delete/new while picking), everything else passes
  # through to the wrapped widget unchanged.
  class Picker(W)
    def initialize(@widget : W, @on_pick : String -> Nil, @on_cancel : -> Nil,
                   @suppress : Array(Char) = [] of Char)
    end

    def handle_key(ev : KeyEvent) : Bool
      case ev.key
      when Key::Esc
        @on_cancel.call
        true
      when Key::Enter
        if v = @widget.selected_value
          @on_pick.call(v)
        end
        true
      when Key::Char
        return true if @suppress.includes?(ev.char)
        @widget.handle_key(ev)
      else
        @widget.handle_key(ev)
      end
    end
  end
end
