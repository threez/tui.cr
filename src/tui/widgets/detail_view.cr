require "../widget/scrollable"
require "../widget/scroll_control"
require "../widget/key_menu"
require "./cell"
require "../data_sources/detail_data_source"

module TUI
  class DetailView
    include Scrollable

    # Default column width reserved for a row's label, before the value
    # column starts — shared by #render_content and #render_line so
    # labels and wrapped continuation lines always align. Override via
    # #initialize's `label_width` for consumers with longer labels.
    DEFAULT_LABEL_WIDTH = 16

    # Fires when the host app should dismiss this DetailView (e.g. its
    # own Esc/"back" binding) — DetailView never pops itself off a nav
    # stack; the host decides what "closing" means.
    property on_close : Proc(Nil)?

    # Applied to every row's label column (see #render_line).
    property label_style : Style = Style.new(bold: true)

    # Applied to the trailing `\` continuation marker on soft-wrapped
    # value lines (see #render_line).
    property wrap_marker_style : Style = Style.new(dim: true)

    @toggle_menu : KeyMenu

    def initialize(@source : DetailDataSource, @label_width : Int32 = DEFAULT_LABEL_WIDTH)
      @focused = true
      @current_id = nil.as(String?)
      @expansions = Set(Symbol).new
      @lines = [] of DetailLine
      @toggle_menu = build_toggle_menu
    end

    # Loads new content. Callers using a Window-hosted DetailView should
    # also call the Window's #reset_scroll afterward — this class has no
    # Scroller of its own to reset (Window owns it).
    def load(id : String) : Nil
      @current_id = id
      @expansions.clear
      rebuild_lines
    end

    def content_size : Int32
      @lines.size
    end

    def title : String
      id = @current_id
      id ? @source.title(id) : "Detail"
    end

    def render_content(buffer : Buffer, scroll : ScrollControl) : Nil
      val_w = buffer.width - @label_width - 2 # 1 leading space + 1 space between label and value
      current_y = 0
      skipped = 0

      @lines.each do |line|
        rendered_rows = render_line(line, val_w)

        if skipped < scroll.offset
          skipped += 1
          next
        end

        rendered_rows.each do |rendered|
          break if current_y >= buffer.height
          buffer.set(current_y, 0, rendered)
          current_y += 1
        end

        break if current_y >= buffer.height
      end
    end

    def handle_key(ev : KeyEvent, scroll : ScrollControl) : Bool
      page = scroll.visible
      case ev.key
      when Key::Up
        scroll.up
        true
      when Key::Down
        scroll.down(total: @lines.size)
        true
      when Key::PageUp
        scroll.up(page)
        true
      when Key::PageDown
        scroll.down(page, total: @lines.size)
        true
      when Key::MouseWheelUp
        scroll.wheel_up
        true
      when Key::MouseWheelDown
        scroll.wheel_down(total: @lines.size)
        true
      else
        @toggle_menu.dispatch(ev)
      end
    end

    def handle_click(local_row : Int32, local_col : Int32, scroll : ScrollControl) : Bool
      false
    end

    def status_hint : String
      " ↑↓/PgUp/PgDn:scroll" + @toggle_menu.hint + "  Esc:back"
    end

    private def rebuild_lines : Nil
      id = @current_id
      @lines = id ? @source.lines(id, @expansions) : [] of DetailLine
    end

    private def toggle(sym : Symbol) : Nil
      if @expansions.includes?(sym)
        @expansions.delete(sym)
      else
        @expansions << sym
      end
      rebuild_lines
    end

    # Assigns toggle keys 'a', 'b', ... to @source.toggles in array order
    # (supports up to 26 toggles) — both dispatch AND the hint text
    # (KeyMenu#hint) are derived from this same registration, so they
    # can never disagree about which letter does what.
    private def build_toggle_menu : KeyMenu
      menu = KeyMenu.new
      chars = ('a'..'z').to_a
      @source.toggles.each_with_index do |sym, i|
        next unless i < chars.size
        ch = chars[i]
        menu.bind(ch, "#{ch}:#{@source.toggle_label(sym)}") { toggle(sym) }
      end
      menu
    end

    private def render_line(line : DetailLine, val_w : Int32) : Array(String)
      label_col = Term.fit(Term.apply(label_style, line.label), @label_width)
      cell = line.value
      text = cell.text

      if text.size <= val_w
        fitted = CellStyle.apply(cell.style, Term.fit(text, val_w))
        [" #{label_col} #{fitted}"]
      else
        # Soft-wrap: break into val_w-wide chunks; continuation lines have blank label
        chunks = [] of String
        pos = 0
        first = true
        while pos < text.size
          chunk = text[pos, val_w - 1]
          lbl = first ? label_col : Term.fit("", @label_width)
          suffix = pos + val_w - 1 < text.size ? Term.apply(wrap_marker_style, "\\") : " "
          styled = CellStyle.apply(cell.style, Term.fit(chunk, val_w - 1))
          chunks << " #{lbl} #{styled}#{suffix}"
          pos += val_w - 1
          first = false
        end
        chunks
      end
    end
  end
end
