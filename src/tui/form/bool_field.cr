require "./form_field"

module TUI
  # Two-state toggle, rendered as `◉ yes  ○ no` / `○ yes  ◉ no`. Wire
  # format is the literal string `"true"` or `"false"` (see
  # `#value`/`#start`). Left/Right and Space are equivalent ways to flip
  # `@bool_pending`; Enter and Esc both commit — there's no cancel path,
  # matching FormField's stated rationale that a bool edit has no
  # sensible discard-in-place gesture.
  class BoolField < FormField
    def initialize
      @bool_pending = false
    end

    def start(current_value : String) : Nil
      @bool_pending = current_value == "true"
    end

    def handle_key(ev : KeyEvent) : Symbol?
      case ev.key
      when Key::Esc, Key::Enter
        :commit
      when Key::Left, Key::Right
        @bool_pending = !@bool_pending
        nil
      when Key::Char
        if ev.char == ' '
          @bool_pending = !@bool_pending
        end
        nil
      else
        nil
      end
    end

    def value : String
      @bool_pending ? "true" : "false"
    end

    def render(buffer : Buffer, y : Int32, x : Int32, width : Int32, height : Int32 = 1, focused : Bool = true) : Nil
      yes = @bool_pending ? "◉ yes" : "○ yes"
      no = @bool_pending ? "○ no" : "◉ no"
      buffer.set(y, x, "#{yes}  #{no}")
    end

    def status_hint : String
      " ←→/Space:toggle  Enter/Esc:commit"
    end
  end
end
