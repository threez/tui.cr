require "../widget/scrollable"
require "../widget/scroll_control"

module TUI
  # A multi-line, editable text area — the Scrollable-hosted counterpart to
  # TextField (src/tui/form/text_field.cr), for standalone editing (e.g. a
  # full-screen editor via `Window.full_screen(screen, TextEdit.new(...))`)
  # rather than one bounded field inside a form. Long lines soft-wrap at an
  # exact character column (not word boundaries — keeps cursor math a
  # simple division, matching vim's default `wrap`), with a trailing
  # marker glyph on every wrapped (non-final) segment of a line, mirroring
  # DetailView's `\` continuation marker for its own soft-wrapped value
  # column. content_size counts *visual* rows (post-wrap), so Window's
  # existing Scroller/scrollbar machinery shows a scrollbar automatically
  # the instant wrapped content overflows the viewport — no separate
  # scrollbar logic needed here.
  #
  # Owns its own cursor (`@text_row`, `@text_col`, into `@text_lines`)
  # because Runtime hides the native terminal cursor for the app's whole
  # lifetime — see `#render_content` for how the cursor is instead drawn
  # as a reverse-video cell, exactly like TextField's `overlay_cursor`.
  class TextEdit
    include Scrollable

    # Appended after every wrapped (non-final) segment of a soft-wrapped
    # line, in the last column — the visual cue that the line continues
    # on the next row rather than having actually ended.
    WRAP_MARKER = "→"

    private record Segment, line : Int32, col_offset : Int32, text : String, wrapped : Bool

    property title : String = "Edit"
    property wrap_marker_style : Style = Style.new(dim: true)

    def initialize(text : String = "")
      @text_lines = text.empty? ? [""] : text.split('\n')
      @text_row = 0
      @text_col = 0
      @visual_rows = [] of Segment
      # No real width yet (nothing has rendered); wrapping is effectively
      # disabled (one segment per line) until #render_content runs and
      # calls #ensure_layout with the actual buffer width — so key
      # handling exercised before the first render still has a consistent
      # (unwrapped) @visual_rows to operate on instead of an empty array.
      @layout_width = Int32::MAX
      @layout_dirty = true
    end

    def value : String
      @text_lines.join('\n')
    end

    def content_size : Int32
      # Layout is width-dependent but content_size is queried by Window
      # before render_content gets this frame's actual buffer width, so
      # this uses whatever width was last laid out — same one-frame-stale
      # tradeoff MarkdownView documents for the same reason; it self-heals
      # next frame. ensure_layout guards against the very first call ever
      # (before any #render_content has run), where @visual_rows would
      # otherwise still be empty.
      ensure_layout(@layout_width)
      @visual_rows.size
    end

    def render_content(buffer : Buffer, scroll : ScrollControl) : Nil
      return if buffer.width < 1 || buffer.height < 1
      ensure_layout(buffer.width)
      cursor_row = cursor_visual_row

      @visual_rows.each_with_index do |seg, i|
        next if i < scroll.offset
        visible_row = i - scroll.offset
        break if visible_row >= buffer.height

        line = seg.wrapped ? Term.fit(seg.text, [buffer.width - 1, 0].max) + Term.apply(wrap_marker_style, WRAP_MARKER) : Term.fit(seg.text, buffer.width)
        if focused? && i == cursor_row
          col = [@text_col - seg.col_offset, seg.text.size].min
          line = overlay_cursor(line, col)
        end
        buffer.set(visible_row, 0, line)
      end

      scroll.reveal(cursor_row)
    end

    def handle_key(ev : KeyEvent, scroll : ScrollControl) : Bool
      ensure_layout(@layout_width)
      case ev.key
      when Key::Enter, Key::Backspace, Key::Delete, Key::Char
        handle_edit_key(ev)
        ensure_layout(@layout_width)
        scroll.reveal(cursor_visual_row)
        true
      when Key::Left, Key::Right, Key::Home, Key::End
        handle_horizontal_key(ev.key)
        scroll.reveal(cursor_visual_row)
        true
      when Key::CtrlA
        handle_horizontal_key(Key::Home)
        scroll.reveal(cursor_visual_row)
        true
      when Key::CtrlE
        handle_horizontal_key(Key::End)
        scroll.reveal(cursor_visual_row)
        true
      when Key::WordLeft
        @text_row, @text_col = word_left_pos
        scroll.reveal(cursor_visual_row)
        true
      when Key::WordRight
        @text_row, @text_col = word_right_pos
        scroll.reveal(cursor_visual_row)
        true
      when Key::WordBackspace
        delete_word_backward
        ensure_layout(@layout_width)
        scroll.reveal(cursor_visual_row)
        true
      when Key::WordDelete
        delete_word_forward
        ensure_layout(@layout_width)
        scroll.reveal(cursor_visual_row)
        true
      when Key::Paste
        handle_paste(ev.text || "")
        ensure_layout(@layout_width)
        scroll.reveal(cursor_visual_row)
        true
      when Key::Up
        move_visual_row(-1)
        scroll.reveal(cursor_visual_row)
        true
      when Key::Down
        move_visual_row(1)
        scroll.reveal(cursor_visual_row)
        true
      when Key::PageUp
        scroll.up(scroll.visible)
        true
      when Key::PageDown
        scroll.down(scroll.visible, total: content_size)
        true
      when Key::MouseWheelUp
        scroll.wheel_up
        true
      when Key::MouseWheelDown
        scroll.wheel_down(total: content_size)
        true
      else
        false
      end
    end

    def handle_click(local_row : Int32, local_col : Int32, scroll : ScrollControl) : Bool
      ensure_layout(@layout_width)
      idx = (local_row + scroll.offset).clamp(0, @visual_rows.size - 1)
      seg = @visual_rows[idx]
      @text_row = seg.line
      @text_col = seg.col_offset + local_col.clamp(0, seg.text.size)
      true
    end

    def status_hint : String
      " type to edit  ^A/^E:line  Alt+←→:word  ↑↓/PgUp/PgDn:scroll"
    end

    private def ensure_layout(width : Int32) : Nil
      return if width == @layout_width && !@layout_dirty
      @layout_width = width
      @layout_dirty = false
      rows = [] of Segment
      @text_lines.each_with_index do |line, li|
        rows.concat(segments_for(li, line, width))
      end
      @visual_rows = rows
    end

    # Splits one logical line into visual Segments for `width` columns.
    # Every non-final segment is `width - 1` chars (reserving the last
    # column for WRAP_MARKER); the final segment gets the full `width`
    # since it has no marker to make room for. A line no longer than
    # `width` is exactly one (unwrapped) segment.
    private def segments_for(line_idx : Int32, line : String, width : Int32) : Array(Segment)
      w = [width, 1].max
      return [Segment.new(line_idx, 0, line, false)] if line.size <= w

      segs = [] of Segment
      pos = 0
      chunk_w = [w - 1, 1].max
      while pos < line.size
        remaining = line.size - pos
        if remaining <= w
          segs << Segment.new(line_idx, pos, line[pos..], false)
          pos += remaining
        else
          segs << Segment.new(line_idx, pos, line[pos, chunk_w], true)
          pos += chunk_w
        end
      end
      segs
    end

    # Index into @visual_rows of the segment containing the cursor.
    private def cursor_visual_row : Int32
      @visual_rows.index { |seg| seg.line == @text_row && @text_col >= seg.col_offset && @text_col <= seg.col_offset + seg.text.size } || 0
    end

    private def move_visual_row(delta : Int32) : Nil
      idx = cursor_visual_row + delta
      return unless idx >= 0 && idx < @visual_rows.size
      seg = @visual_rows[idx]
      want_col = @text_col - (@visual_rows[cursor_visual_row].col_offset)
      @text_row = seg.line
      @text_col = seg.col_offset + [want_col, seg.text.size].min
    end

    # Reverse-videos the single character cell at `col` (or an appended
    # trailing space standing in for "past the last character") — copied
    # from TextField#overlay_cursor, same rationale: no OS cursor exists
    # since Runtime hides it for the app's whole lifetime.
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
      @layout_dirty = true # force re-wrap: text changed
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
      when Key::Home
        @text_col = 0
      when Key::End
        @text_col = @text_lines[@text_row].size
      end
    end

    # Target {row, col} for word-left (Alt/Ctrl+Left): skip any whitespace
    # immediately before the cursor, then skip backward through
    # non-whitespace to the start of that run — the same "stop at the
    # start of the previous word" convention readline/most terminal
    # editors use for Alt-B. Wraps to the end of the previous line at
    # column 0, mirroring plain Left's line-wrap.
    private def word_left_pos : {Int32, Int32}
      row, col = @text_row, @text_col
      if col == 0
        return {row, col} if row == 0
        return {row - 1, @text_lines[row - 1].size}
      end

      line = @text_lines[row]
      while col > 0 && line[col - 1].whitespace?
        col -= 1
      end
      while col > 0 && !line[col - 1].whitespace?
        col -= 1
      end
      {row, col}
    end

    # Target {row, col} for word-right (Alt/Ctrl+Right): skip forward
    # through the current word (non-whitespace), then skip forward
    # through trailing whitespace, landing at the start of the next word
    # — the Alt-F counterpart to #word_left_pos. Wraps to the start of the
    # next line at end-of-line, mirroring plain Right's line-wrap.
    private def word_right_pos : {Int32, Int32}
      row, col = @text_row, @text_col
      line = @text_lines[row]
      if col >= line.size
        return {row, col} if row >= @text_lines.size - 1
        return {row + 1, 0}
      end

      size = line.size
      while col < size && !line[col].whitespace?
        col += 1
      end
      while col < size && line[col].whitespace?
        col += 1
      end
      {row, col}
    end

    # Deletes from the cursor back to #word_left_pos in one edit op
    # (Alt/Option+Backspace) — falls back to plain Backspace's
    # merge-with-previous-line behavior when the target lands on a
    # different row (there's no "word" to delete across a line break,
    # just the break itself).
    private def delete_word_backward : Nil
      target_row, target_col = word_left_pos
      if target_row != @text_row
        handle_edit_key(KeyEvent.new(Key::Backspace))
        return
      end

      line = @text_lines[@text_row]
      @text_lines[@text_row] = line[0...target_col] + line[@text_col..]
      @text_col = target_col
      @layout_dirty = true
    end

    # Deletes from the cursor forward to #word_right_pos in one edit op
    # (Alt/Option+Delete) — falls back to plain Delete's
    # merge-with-next-line behavior when the target lands on a different
    # row, same rationale as #delete_word_backward.
    private def delete_word_forward : Nil
      target_row, target_col = word_right_pos
      if target_row != @text_row
        handle_edit_key(KeyEvent.new(Key::Delete))
        return
      end

      line = @text_lines[@text_row]
      @text_lines[@text_row] = line[0...@text_col] + line[target_col..]
      @layout_dirty = true
    end

    # Inserts pasted text at the cursor in one edit op instead of one
    # Key::Char insert per character — splits `text` on newlines, splices
    # the first segment into the current line, and inserts any remaining
    # segments as whole new lines, leaving the cursor at the end of the
    # last inserted segment (matching where a real Enter+Char sequence
    # would land, without the flood of KeyEvents that would imply).
    private def handle_paste(text : String) : Nil
      return if text.empty?
      parts = text.split('\n')

      line = @text_lines[@text_row]
      before = line[0...@text_col]
      after = line[@text_col..]

      if parts.size == 1
        @text_lines[@text_row] = before + parts[0] + after
        @text_col += parts[0].size
      else
        @text_lines[@text_row] = before + parts[0]
        parts[1...-1].each_with_index do |part, i|
          @text_lines.insert(@text_row + 1 + i, part)
        end
        last_index = @text_row + parts.size - 1
        @text_lines.insert(last_index, parts.last + after)
        @text_row = last_index
        @text_col = parts.last.size
      end
      @layout_dirty = true
    end
  end
end
