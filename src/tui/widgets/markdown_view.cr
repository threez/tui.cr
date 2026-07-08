require "../widget/scrollable"
require "../widget/scroll_control"
require "../markdown/block"
require "../markdown/parser"
require "../markdown/layout"

module TUI
  # Renders a Markdown source string: numbered headings with per-level
  # emphasis (since a terminal can't grow font size), real word-wrapped
  # paragraphs/list items/blockquotes preserving inline styling, nested
  # list indentation with continuation lines aligned under the text (not
  # the marker), and GFM tables with alignment-aware column widths drawn
  # with box-drawing borders. Parsing/wrapping/layout are hand-rolled in
  # TUI::Markdown (this library has zero runtime dependencies) — see
  # TUI::Markdown::Parser/Wrap/Layout for the algorithms; this class is
  # just the Scrollable host: styling properties, caching, and the
  # standard scroll-key handling every other Scrollable already has.
  class MarkdownView
    include Scrollable

    # Heading styles by level (index 0 = h1), decreasing emphasis since
    # Style has no font-size — numbering (see #number_headings) is the
    # primary way level is conveyed, this is a secondary visual cue.
    property heading_styles : Array(Style) = [
      Style.new(bold: true, fg: TUI.color(:cyan)),
      Style.new(bold: true),
      Style.new(bold: true, dim: true),
      Style.new(dim: true),
      Style.new(dim: true),
      Style.new(dim: true),
    ]

    # Nested-outline numbering ("1.2.3  Title") in front of every
    # heading. Disable to keep indentation/styling but drop the prefix.
    property? number_headings : Bool = true
    property heading_indent_step : Int32 = 2

    property bold_style : Style = Style.new(bold: true)
    property italic_style : Style = Style.new(italic: true)
    property bold_italic_style : Style = Style.new(bold: true, italic: true)
    property code_style : Style = Style.new(fg: TUI.color(:yellow))
    property link_style : Style = Style.new(fg: TUI.color(:blue))

    property quote_style : Style = Style.new(fg: TUI.color(:gray), dim: true)
    property quote_indent_step : Int32 = 2

    property list_marker_style : Style = Style.new(fg: TUI.color(:gray))
    property list_indent_step : Int32 = 3
    property list_bullet_glyphs : Array(String) = ["•", "◦", "▪"]

    property table_border_style : Style = Style.new(fg: TUI.color(:gray))
    property table_header_style : Style = Style.new(bold: true)

    property hrule_style : Style = Style.new(fg: TUI.color(:gray))

    # Set by a host app (e.g. to a document's filename); shown as the
    # hosting Window's border title, same convention as DetailView#title.
    property title : String = "Markdown"

    def initialize(source : String = "")
      @focused = true
      @blocks = [] of Markdown::Block
      @layout_rows = [] of Array(Markdown::InlineRun)
      @layout_width = -1
      @last_known_width = 80
      load(source) unless source.empty?
    end

    # Replaces the rendered content and invalidates the cached layout
    # (see #content_size for why layout is cached at all) so the next
    # #content_size/#render_content call re-lays-out unconditionally,
    # even if the new document happens to need the same width as the
    # old cached layout.
    def load(source : String) : Nil
      inline_config = Markdown::Inline::Config.new(
        bold_style: bold_style,
        italic_style: italic_style,
        bold_italic_style: bold_italic_style,
        code_style: code_style,
        link_style: link_style,
      )
      @blocks = Markdown::Parser.parse(source, @number_headings, inline_config)
      @layout_width = -1
    end

    # Reports the physical row count for the width this content was LAST
    # actually rendered at (#render_content updates that width every
    # call) — Window#render calls #content_size before it has built the
    # buffer that would tell content this frame's width (confirmed by
    # reading Window#render: `total = @content.content_size` runs before
    # `inner = Buffer.new(inner_width, ...)`), so there is structurally
    # no way to answer for the CURRENT frame's width here. This is stale
    # by exactly one frame during an active resize (used only for
    # Scroller#clamp's max-offset math) and self-heals the same frame
    # #render_content next runs with the real width — the same
    # resize-tolerance philosophy Scroller#clamp itself already relies
    # on, rather than widening Scrollable's abstract contract for this
    # one widget's benefit.
    def content_size : Int32
      ensure_layout(@last_known_width)
      @layout_rows.size
    end

    def render_content(buffer : Buffer, scroll : ScrollControl) : Nil
      @last_known_width = buffer.width
      ensure_layout(buffer.width)

      current_y = 0
      @layout_rows.each_with_index do |row, i|
        next if i < scroll.offset
        break if current_y >= buffer.height
        buffer.set(current_y, 0, row.join { |r| Term.apply(r.style, r.text) })
        current_y += 1
      end
    end

    def handle_key(ev : KeyEvent, scroll : ScrollControl) : Bool
      page = scroll.visible
      case ev.key
      when Key::Up
        scroll.up
        true
      when Key::Down
        scroll.down(total: @layout_rows.size)
        true
      when Key::PageUp
        scroll.up(page)
        true
      when Key::PageDown
        scroll.down(page, total: @layout_rows.size)
        true
      when Key::MouseWheelUp
        scroll.wheel_up
        true
      when Key::MouseWheelDown
        scroll.wheel_down(total: @layout_rows.size)
        true
      else
        false
      end
    end

    def handle_click(local_row : Int32, local_col : Int32, scroll : ScrollControl) : Bool
      false
    end

    def status_hint : String
      " ↑↓/PgUp/PgDn:scroll  Esc:back"
    end

    private def ensure_layout(width : Int32) : Nil
      return if width == @layout_width
      @layout_rows = Markdown::Layout.layout(@blocks, width, layout_config)
      @layout_width = width
    end

    private def layout_config : Markdown::Layout::Config
      Markdown::Layout::Config.new(
        heading_styles: heading_styles,
        heading_indent_step: heading_indent_step,
        list_marker_style: list_marker_style,
        list_indent_step: list_indent_step,
        list_bullet_glyphs: list_bullet_glyphs,
        quote_style: quote_style,
        quote_indent_step: quote_indent_step,
        table_border_style: table_border_style,
        table_header_style: table_header_style,
        hrule_style: hrule_style,
      )
    end
  end
end
