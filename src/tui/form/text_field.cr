require "./form_field"

module TUI
  # Multi-line text editor. Wire format is `@text_lines` joined with `\n`
  # (see `#value`/`#start`), so a persisted value round-trips through
  # plain newline-delimited text with no other escaping. Esc commits
  # (there's no discard-in-place gesture, per FormField's stated Esc
  # convention). Owns its own cursor/scroll state (`@text_row`,
  # `@text_col`, `@text_row_offset`) because Runtime hides the native
  # terminal cursor for the app's whole lifetime — see `#render` for how
  # the cursor is instead drawn as a reverse-video cell.
  class TextField < FormField
    def initialize
      @text_lines = [""]
      @text_row = 0
      @text_col = 0
      @text_row_offset = 0
    end

    def start(current_value : String) : Nil
      @text_lines = current_value.empty? ? [""] : current_value.split('\n')
      @text_row = 0
      @text_col = @text_lines[0].size
      @text_row_offset = 0
    end

    def handle_key(ev : KeyEvent) : Symbol?
      case ev.key
      when Key::Esc
        :commit
      when Key::Enter, Key::Backspace, Key::Delete, Key::Char
        handle_edit_key(ev)
        nil
      when Key::Left, Key::Right, Key::Up, Key::Down, Key::Home, Key::End
        handle_cursor_key(ev.key)
        nil
      else
        nil
      end
    end

    def value : String
      @text_lines.join('\n')
    end

    # Local (row, col) offset from the (y, x) origin passed to `render`,
    # where the native terminal cursor should be placed while this field
    # is being edited. Row is the index into @text_lines the cursor
    # currently sits on — `render` draws every line, so this must track
    # which one is active rather than assuming a fixed row.
    def cursor_offset : {row: Int32, col: Int32}
      {row: @text_row, col: @text_col}
    end

    # `height` bounds how many buffer rows this field may draw into —
    # one row per line in @text_lines, scrolled minimally so @text_row is
    # always visible (extra lines simply scroll out of the fixed window
    # rather than growing it or hiding the cursor's line). The currently
    # edited line gets its cursor column reverse-videoed in-place, since
    # Runtime hides the native terminal cursor for the app's whole
    # lifetime (see Runtime#run) with no hook to show/move it around a
    # single frame's flush. `focused` gates that cursor decoration — pass
    # false when drawing a field's persisted state outside an active edit
    # session, so a throwaway preview instance doesn't show a misleading
    # "still editing" cursor for a field nothing is actually editing.
    def render(buffer : Buffer, y : Int32, x : Int32, width : Int32, height : Int32 = 1, focused : Bool = true) : Nil
      max_offset = [@text_lines.size - height, 0].max
      offset = @text_row_offset.clamp(0, max_offset)
      offset = @text_row if @text_row < offset
      offset = @text_row - height + 1 if @text_row >= offset + height
      @text_row_offset = offset

      @text_lines.each_with_index do |line, i|
        next if i < offset
        visible_row = i - offset
        break if visible_row >= height
        fitted = Term.fit(line, width)
        if focused && i == @text_row
          # @text_col indexes the raw (untruncated) line; if Term.fit had
          # to cut the line short, clamp to the last visible column so
          # the cursor still shows up there rather than silently
          # vanishing past the truncation point.
          col = [@text_col, width - 1].min
          fitted = overlay_cursor(fitted, col)
        end
        buffer.set(y + visible_row, x, fitted)
      end
    end

    def status_hint : String
      " type to edit  Esc:commit"
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
      when Key::Enter
        @text_lines.insert(@text_row + 1, @text_lines[@text_row][@text_col..])
        @text_lines[@text_row] = @text_lines[@text_row][0...@text_col]
        @text_row += 1
        @text_col = 0
      when Key::Backspace
        if @text_col > 0
          line = @text_lines[@text_row]
          @text_lines[@text_row] = line[0...@text_col - 1] + line[@text_col..]
          @text_col -= 1
        elsif @text_row > 0
          prev_len = @text_lines[@text_row - 1].size
          @text_lines[@text_row - 1] += @text_lines[@text_row]
          @text_lines.delete_at(@text_row)
          @text_row -= 1
          @text_col = prev_len
        end
      when Key::Delete
        line = @text_lines[@text_row]
        if @text_col < line.size
          @text_lines[@text_row] = line[0...@text_col] + line[@text_col + 1..]
        elsif @text_row < @text_lines.size - 1
          @text_lines[@text_row] += @text_lines[@text_row + 1]
          @text_lines.delete_at(@text_row + 1)
        end
      when Key::Char
        line = @text_lines[@text_row]
        @text_lines[@text_row] = line[0...@text_col] + ev.char.to_s + line[@text_col..]
        @text_col += 1
      end
    end

    private def handle_cursor_key(key : Key) : Nil
      case key
      when Key::Left, Key::Right
        handle_horizontal_key(key)
      when Key::Up, Key::Down
        handle_vertical_key(key)
      when Key::Home
        @text_col = 0
      when Key::End
        @text_col = @text_lines[@text_row].size
      end
    end

    private def handle_horizontal_key(key : Key) : Nil
      case key
      when Key::Left
        if @text_col > 0
          @text_col -= 1
        elsif @text_row > 0
          @text_row -= 1
          @text_col = @text_lines[@text_row].size
        end
      when Key::Right
        line = @text_lines[@text_row]
        if @text_col < line.size
          @text_col += 1
        elsif @text_row < @text_lines.size - 1
          @text_row += 1
          @text_col = 0
        end
      end
    end

    private def handle_vertical_key(key : Key) : Nil
      case key
      when Key::Up
        if @text_row > 0
          @text_row -= 1
          @text_col = [@text_col, @text_lines[@text_row].size].min
        end
      when Key::Down
        if @text_row < @text_lines.size - 1
          @text_row += 1
          @text_col = [@text_col, @text_lines[@text_row].size].min
        end
      end
    end
  end
end
