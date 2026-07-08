require "./form_field"

module TUI
  # Single-line text field. Wire format is the raw text itself (see
  # `#value`/`#start`) — no newline handling of any kind, unlike
  # ScrollableField (src/tui/form/scrollable_field.cr), which is where
  # multi-line free-text editing now lives. Esc and Enter both commit —
  # there's no discard-in-place gesture (per FormField's stated Esc
  # convention) and, being single-line, there's nowhere sensible for
  # Enter to put a newline anyway.
  # Owns its own cursor/scroll state (`@col`, `@col_offset`) because
  # Runtime hides the native terminal cursor for the app's whole
  # lifetime — see `#render` for how the cursor is instead drawn as a
  # reverse-video cell.
  class InputField < FormField
    def initialize
      @text = ""
      @col = 0
      @col_offset = 0
    end

    def start(current_value : String) : Nil
      @text = current_value
      @col = @text.size
      @col_offset = 0
    end

    def handle_key(ev : KeyEvent) : Symbol?
      case ev.key
      when Key::Esc, Key::Enter
        :commit
      when Key::Backspace, Key::Delete, Key::Char
        handle_edit_key(ev)
        nil
      when Key::Left, Key::Right, Key::Home, Key::End
        handle_cursor_key(ev.key)
        nil
      else
        nil
      end
    end

    def value : String
      @text
    end

    # Local column offset from the `x` origin passed to `render`, where
    # the native terminal cursor should be placed while this field is
    # being edited.
    def cursor_offset : {row: Int32, col: Int32}
      {row: 0, col: @col}
    end

    def render(buffer : Buffer, y : Int32, x : Int32, width : Int32, height : Int32 = 1, focused : Bool = true) : Nil
      offset = @col_offset.clamp(0, [@text.size - width + 1, 0].max)
      offset = @col if @col < offset
      offset = @col - width + 1 if @col >= offset + width
      @col_offset = offset

      visible = @text[offset..]
      fitted = Term.fit(visible, width)
      if focused
        col = [@col - offset, width - 1].min
        fitted = overlay_cursor(fitted, col)
      end
      buffer.set(y, x, fitted)
    end

    def status_hint : String
      " type to edit  Enter/Esc:commit"
    end

    # Reverse-videos the single character cell at `col` (or an appended
    # trailing space standing in for "past the last character"), to make
    # the insertion point visible without relying on the native terminal
    # cursor. Safe against Buffer#set's per-call ANSI tracking: bracketing
    # one character with reverse+reset isolates it from the rest of the
    # line's (plain) styling.
    private def overlay_cursor(s : String, col : Int32) : String
      chars = s.chars
      chars << ' ' if col >= chars.size
      return s if col >= chars.size
      before = chars[0...col].join
      after = chars[(col + 1)..].join
      "#{before}#{Term::REVERSE}#{chars[col]}#{Term::RESET}#{after}"
    end

    private def handle_edit_key(ev : KeyEvent) : Nil
      case ev.key
      when Key::Backspace
        if @col > 0
          @text = @text[0...@col - 1] + @text[@col..]
          @col -= 1
        end
      when Key::Delete
        if @col < @text.size
          @text = @text[0...@col] + @text[@col + 1..]
        end
      when Key::Char
        @text = @text[0...@col] + ev.char.to_s + @text[@col..]
        @col += 1
      end
    end

    private def handle_cursor_key(key : Key) : Nil
      case key
      when Key::Left
        @col -= 1 if @col > 0
      when Key::Right
        @col += 1 if @col < @text.size
      when Key::Home
        @col = 0
      when Key::End
        @col = @text.size
      end
    end
  end
end
