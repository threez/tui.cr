require "./form_field"

module TUI
  # Single-select from a fixed `Array(FormEnumOption)`, tracked by
  # `@focus_index` — focus and selection are the same thing here, unlike
  # FlagsField where they're independent. Wire format is the focused
  # option's `wire_value` (see `#value`/`#start`); `#value` falls back to
  # `""` if `@options` is empty or `@focus_index` is somehow out of range,
  # rather than raising. Up/Down move focus; Space or Enter commit; Esc
  # cancels without writing back, per FormField's stated rationale that a
  # picker with nothing chosen yet has no sensible commit value.
  class EnumField < FormField
    def initialize(@options : Array(FormEnumOption))
      @focus_index = 0
    end

    def start(current_value : String) : Nil
      @focus_index = @options.index { |option| option.wire_value == current_value } || 0
    end

    def handle_key(ev : KeyEvent) : Symbol?
      return nil if @options.empty?
      case ev.key
      when Key::Esc
        :cancel
      when Key::Enter
        :commit
      when Key::Up
        @focus_index = (@focus_index - 1).clamp(0, @options.size - 1)
        nil
      when Key::Down
        @focus_index = (@focus_index + 1).clamp(0, @options.size - 1)
        nil
      when Key::Char
        ev.char == ' ' ? :commit : nil
      else
        nil
      end
    end

    def value : String
      @options[@focus_index]?.try(&.wire_value) || ""
    end

    def render(buffer : Buffer, y : Int32, x : Int32, width : Int32, height : Int32 = 1, focused : Bool = true) : Nil
      @options.each_with_index do |opt, i|
        break if i >= height
        marker = i == @focus_index ? "◉" : "○"
        buffer.set(y + i, x, "#{marker} #{opt.label}")
      end
    end

    def status_hint : String
      " ↑↓:choose  Space:toggle  Enter:commit  Esc:cancel"
    end
  end
end
