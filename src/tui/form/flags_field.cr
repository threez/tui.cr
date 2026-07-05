require "./form_field"

module TUI
  # Multi-select from a fixed `Array(FormEnumOption)`, tracked by a
  # `Set(Int32)` of selected indices kept independent from
  # `@focus_index` — unlike EnumField, where focus *is* the selection.
  # Wire format is a decimal string of a bitmask, bit `i` set meaning
  # option `i` is selected; `#value` composes that bitmask and
  # `#decode_flags` (called from `#start`) parses it back. Up/Down move
  # focus; Space toggles the focused option in/out of `@selected`; Enter
  # commits; Esc cancels without writing back, per FormField's stated
  # rationale that a picker with nothing chosen yet has no sensible
  # commit value.
  class FlagsField < FormField
    # Applied to the focused checkbox row (see #render).
    property cursor_style : Style = Style.new(reverse: true)

    def initialize(@options : Array(FormEnumOption))
      @focus_index = 0
      @selected = Set(Int32).new
    end

    def start(current_value : String) : Nil
      @focus_index = 0
      @selected = decode_flags(current_value)
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
        if ev.char == ' '
          if @selected.includes?(@focus_index)
            @selected.delete(@focus_index)
          else
            @selected << @focus_index
          end
        end
        nil
      else
        nil
      end
    end

    def value : String
      composed = 0_i64
      @selected.each { |i| composed |= (1_i64 << i) }
      composed.to_s
    end

    # `focused` gates the reverse-video keyboard-cursor row — pass false
    # when drawing a field's persisted state outside an active edit
    # session, so an always-visible option list doesn't show a stray
    # highlight on whichever row @focus_index happens to default to (0,
    # from #initialize, unrelated to @selected).
    def render(buffer : Buffer, y : Int32, x : Int32, width : Int32, height : Int32 = 1, focused : Bool = true) : Nil
      @options.each_with_index do |opt, i|
        break if i >= height
        marker = @selected.includes?(i) ? "[x]" : "[ ]"
        highlight = focused && i == @focus_index
        prefix = highlight ? Term.apply(cursor_style, "#{marker} #{opt.label}") : "#{marker} #{opt.label}"
        buffer.set(y + i, x, prefix)
      end
    end

    def status_hint : String
      " ↑↓:choose  Space:toggle  Enter:commit  Esc:cancel"
    end

    private def decode_flags(raw : String) : Set(Int32)
      bits = raw.to_i64? || 0_i64
      result = Set(Int32).new
      @options.each_index { |i| result << i if bits.bit(i) == 1 }
      result
    end
  end
end
