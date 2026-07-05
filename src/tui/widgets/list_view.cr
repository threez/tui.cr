require "../widget/scrollable"
require "../widget/scroll_control"
require "../widget/scroller"
require "../widget/click_tracker"
require "../data_sources/list_data_source"

module TUI
  abstract class ListView
    include Scrollable

    # Fires with the newly-current row's index whenever the cursor moves
    # (arrows, page keys, mouse wheel, click, filtering, sort change,
    # #reload) — a live "what's highlighted right now" signal, e.g. for
    # driving a detail pane alongside the list.
    property on_select : Proc(Int32, Nil)?

    # Fires with the selected row's index on Enter or a confirmed click
    # (see ClickTracker) — the "open/commit this row" signal, distinct
    # from #on_select's continuous highlight tracking.
    property on_activate : Proc(Int32, Nil)?

    # Applied to #title's text when this list is focused (see #title).
    property title_style : Style = Style.new(bold: true)

    # Layered (via Term.overlay) onto the cursor row when this list is
    # focused — see #render_content.
    property cursor_focused_style : Style = Style.new(reverse: true)

    # Layered onto the cursor row when this list is NOT focused — a
    # weaker cue than #cursor_focused_style, so cursor position still
    # shows without implying the list is active.
    property cursor_unfocused_style : Style = Style.new(bold: true)

    # Applied to the `/filter` prompt line while filtering is active.
    property filter_prompt_style : Style = Style.new(bold: true)

    # Whether the filter/search input is currently capturing keystrokes.
    # A host app dispatching its own global key menu on top of this widget
    # should skip that dispatch entirely while this is true — otherwise a
    # global single-char binding (e.g. a "m" or "q" shortcut) hijacks a
    # keystroke the user is typing into the filter text instead of it being
    # appended to the filter.
    def filter_active? : Bool
      @filter_active
    end

    def initialize(@source : ListDataSource)
      @cursor = 0
      @filter = ""
      @filter_active = false
      @sort = @source.sort_keys.first? || :name
      @click_tracker = ClickTracker.new
    end

    def reload : Nil
      @source.reload(@filter, @sort)
      @cursor = 0
      notify_select
    end

    def selected_index : Int32?
      @cursor if @source.size > 0
    end

    def content_size : Int32
      @source.size
    end

    def title : String
      title_text = @source.title(@filter, @sort)
      focused? ? Term.apply(title_style, title_text) : title_text
    end

    def render_content(buffer : Buffer, scroll : ScrollControl) : Nil
      render_header(buffer)

      offset = scroll.offset
      limit = buffer.height - (@filter_active ? 1 : 0)

      @source.size.times do |i|
        next if i < offset
        row_y = content_row_offset + (i - offset)
        break if row_y >= limit

        pointer = i == @cursor ? "▸" : " "
        row_str = " #{pointer}#{row_content(i)}"

        if i == @cursor && focused?
          fitted = Term.fit(row_str, buffer.width)
          buffer.set(row_y, 0, Term.overlay(fitted, Term.escape(cursor_focused_style)))
        elsif i == @cursor
          fitted = Term.fit(row_str, buffer.width)
          buffer.set(row_y, 0, Term.overlay(fitted, Term.escape(cursor_unfocused_style)))
        else
          buffer.set(row_y, 0, Term.fit(row_str, buffer.width))
        end
      end

      if @filter_active
        prompt = Term.fit("/#{@filter}█", buffer.width)
        buffer.set(buffer.height - 1, 0, Term.apply(filter_prompt_style, prompt))
      end
    end

    def handle_key(ev : KeyEvent, scroll : ScrollControl) : Bool
      if @filter_active
        handle_filter_key(ev, scroll)
      else
        handle_nav_key(ev, scroll)
      end
    end

    def handle_click(local_row : Int32, local_col : Int32, scroll : ScrollControl) : Bool
      if idx = row_at(local_row, scroll)
        @cursor = idx
        scroll.reveal(@cursor)
        notify_select
        if @click_tracker.register(idx)
          @filter_active = false
          @on_activate.try &.call(idx)
        end
      end
      true
    end

    def status_hint : String
      if @filter_active
        " Type to filter  ↑↓:navigate  Enter:open detail  Esc:cancel search"
      else
        " ↑↓:navigate  Enter:select  /:search  s:sort"
      end
    end

    # Draw whatever goes on row 0 above the data rows (e.g. a table's
    # column header). No-op by default — a plain list has no header row.
    protected def render_header(buffer : Buffer) : Nil
    end

    # How many rows of inset this content draws above its data rows
    # (e.g. a table's header row). Base ListView has none. A subclass
    # should declare this with the `scroll header:` macro rather than
    # overriding directly, so Window's #header_rows query (Scrollable's
    # contract) can never drift from what #render_content actually draws.
    protected def content_row_offset : Int32
      0
    end

    # Satisfies Scrollable#header_rows by delegating to #content_row_offset
    # — kept as one method, not two independently-set numbers, so Window's
    # scroll-viewport math can never disagree with where #render_content
    # actually starts drawing data rows.
    def header_rows : Int32
      content_row_offset
    end

    # The content string for content-row `index`, before the leading
    # " {pointer}" prefix and before width-fitting/highlight styling
    # (those stay in `render_content`, shared by every subclass).
    abstract def row_content(index : Int32) : String

    # Local row -> content row index, or nil if the click landed outside
    # the data-row area (header, filter prompt).
    private def row_at(local_row : Int32, scroll : ScrollControl) : Int32?
      offset = content_row_offset
      return nil if local_row < offset
      idx = scroll.offset + (local_row - offset)
      idx if idx >= 0 && idx < @source.size
    end

    private def handle_filter_key(ev : KeyEvent, scroll : ScrollControl) : Bool
      case ev.key
      when Key::Up, Key::Down, Key::PageUp, Key::PageDown, Key::MouseWheelUp, Key::MouseWheelDown
        handle_nav_key(ev, scroll)
      when Key::Enter
        @filter_active = false
        if idx = selected_index
          @on_activate.try &.call(idx)
        end
        true
      when Key::Esc
        @filter_active = false
        @filter = ""
        reload
        true
      when Key::Backspace
        @filter = @filter[0...-1] unless @filter.empty?
        @source.reload(@filter, @sort)
        @cursor = 0
        scroll.reset
        notify_select
        true
      when Key::Char
        @filter += ev.char.to_s
        @source.reload(@filter, @sort)
        @cursor = 0
        scroll.reset
        notify_select
        true
      else
        false
      end
    end

    private def handle_nav_key(ev : KeyEvent, scroll : ScrollControl) : Bool
      case ev.key
      when Key::Up, Key::Down, Key::PageUp, Key::PageDown, Key::MouseWheelUp, Key::MouseWheelDown
        handle_movement_key(ev.key, scroll)
        true
      when Key::Enter
        if idx = selected_index
          @on_activate.try &.call(idx)
        end
        true
      when Key::Char
        handle_nav_char(ev.char)
      else
        false
      end
    end

    private def handle_movement_key(key : Key, scroll : ScrollControl) : Nil
      count = @source.size
      case key
      when Key::Up
        if @cursor > 0
          @cursor -= 1
          scroll.reveal(@cursor)
          notify_select
        end
      when Key::Down
        if @cursor < count - 1
          @cursor += 1
          scroll.reveal(@cursor)
          notify_select
        end
      when Key::PageUp
        page = scroll.visible
        @cursor = [@cursor - page, 0].max
        scroll.up(page)
        notify_select
      when Key::PageDown
        page = scroll.visible
        @cursor = [@cursor + page, [count - 1, 0].max].min
        scroll.down(page, total: count)
        notify_select
      when Key::MouseWheelUp
        scroll.wheel_up
        @cursor = [@cursor - Scroller::WHEEL_STEP, 0].max
        scroll.reveal(@cursor)
        notify_select
      when Key::MouseWheelDown
        scroll.wheel_down(total: count)
        @cursor = [@cursor + Scroller::WHEEL_STEP, [count - 1, 0].max].min
        scroll.reveal(@cursor)
        notify_select
      end
    end

    private def handle_nav_char(char : Char) : Bool
      case char
      when '/'
        @filter_active = true
        true
      when 's'
        keys = @source.sort_keys
        if keys.size > 1
          idx = keys.index(@sort) || 0
          @sort = keys[(idx + 1) % keys.size]
          @source.reload(@filter, @sort)
          notify_select
        end
        true
      else
        false
      end
    end

    private def notify_select : Nil
      if idx = selected_index
        @on_select.try &.call(idx)
      end
    end
  end
end
