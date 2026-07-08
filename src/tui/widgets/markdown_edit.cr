require "./text_edit"
require "../markdown/layout"

module TUI
  # A TextEdit that highlights Markdown syntax as you type — headings,
  # list markers, and blockquote prefixes (line-prefix syntax, detected
  # from one line alone), plus bold/italic/strikethrough/inline-code
  # spans within each line. Deliberately does NOT track multi-line
  # constructs like fenced
  # code blocks — that would require re-parsing surrounding lines on
  # every keystroke, a much heavier cost for a live editor than a
  # read-only viewer pays once per render. Reuses
  # Markdown::Layout::Config's existing heading/list/quote style choices
  # so a highlighted line looks consistent with how MarkdownView would
  # eventually render the same content, rather than inventing a second,
  # unrelated palette.
  #
  # Inline spans are found with a small local scanner rather than reusing
  # Markdown::Inline.parse — that scanner *strips* delimiters
  # (`**bold**` becomes the 4-character-shorter "bold") for MarkdownView,
  # a read-only renderer where the raw source never needs to stay
  # editable. TextEdit's #highlighter contract requires every character
  # of the input line back, unchanged, just re-styled (see TextEdit's
  # #highlighter doc comment) — an editor needs `**`/`` ` `` to stay
  # visible and at their original column so the cursor and edits still
  # land in the right place. #inline_cells below styles delimiters
  # (dimmed) and their contents (bold/italic/code) separately without
  # ever removing a character.
  #
  # This is TextEdit's syntax-agnostic #highlighter hook wired to one
  # particular syntax, not a special case TextEdit itself knows about —
  # any other syntax could plug in the same way via its own subclass.
  class MarkdownEdit < TextEdit
    HEADING_PREFIX    = /^(\#{1,6})(\s+)/
    LIST_PREFIX       = /^(\s*)([-*+]|\d+\.)(\s+)/
    BLOCKQUOTE_PREFIX = /^(>\s?)/

    property bold_style : Style = Style.new(bold: true)
    property italic_style : Style = Style.new(italic: true)
    property strikethrough_style : Style = Style.new(strikethrough: true)
    property code_style : Style = Style.new(fg: TUI.color(:yellow))
    property delimiter_style : Style = Style.new(dim: true)

    def initialize(text : String = "", @config : Markdown::Layout::Config = Markdown::Layout::Config.new)
      super(text)
      self.highlighter = ->(line : String) { highlight(line) }
    end

    private def highlight(line : String) : Array(Cell)
      if m = line.match(HEADING_PREFIX)
        level = m[1].size
        style = @config.heading_styles[[level - 1, @config.heading_styles.size - 1].min]
        prefix = m[0]
        rest = line[prefix.size..]
        return [Cell.new(prefix, style)] + inline_cells(rest, style)
      end

      if m = line.match(LIST_PREFIX)
        prefix = m[0]
        rest = line[prefix.size..]
        return [Cell.new(prefix, @config.list_marker_style)] + inline_cells(rest)
      end

      if m = line.match(BLOCKQUOTE_PREFIX)
        prefix = m[0]
        rest = line[prefix.size..]
        return [Cell.new(prefix, @config.quote_style)] + inline_cells(rest, @config.quote_style)
      end

      inline_cells(line)
    end

    # Scans `text` for `**bold**`/`*italic*`/`` `code` `` spans, keeping
    # every character (including the delimiters themselves, dimmed
    # rather than dropped) so the result satisfies TextEdit#highlighter's
    # length/content-preserving contract. Deliberately simpler than
    # Markdown::Inline.parse: no link/escape handling, no nested-style
    # composition — just enough to color common inline syntax while
    # typing without corrupting cursor/click column math.
    private def inline_cells(text : String, base_style : Style = Style.new) : Array(Cell)
      cells = [] of Cell
      chars = text.chars
      i = 0
      plain = String::Builder.new
      flush = -> {
        s = plain.to_s
        cells << Cell.new(s, base_style) unless s.empty?
        plain = String::Builder.new
      }

      while i < chars.size
        if chars[i] == '`'
          close = chars.index('`', i + 1)
          if close
            flush.call
            cells << Cell.new("`", delimiter_style)
            cells << Cell.new(chars[(i + 1)...close].join, code_style)
            cells << Cell.new("`", delimiter_style)
            i = close + 1
            next
          end
        elsif chars[i] == '*'
          run_len = chars[i + 1]? == '*' ? 2 : 1
          close = find_closing_run(chars, i + run_len, '*', run_len)
          if close
            flush.call
            marker = "*" * run_len
            style = run_len == 2 ? bold_style : italic_style
            cells << Cell.new(marker, delimiter_style)
            cells << Cell.new(chars[(i + run_len)...close].join, style)
            cells << Cell.new(marker, delimiter_style)
            i = close + run_len
            next
          end
        elsif chars[i] == '~' && chars[i + 1]? == '~'
          # GFM strikethrough is always exactly `~~`, unlike `*`
          # emphasis's 1/2-run distinction — a single `~` has no special
          # meaning and is left as literal text (falls through below).
          close = find_closing_run(chars, i + 2, '~', 2)
          if close
            flush.call
            cells << Cell.new("~~", delimiter_style)
            cells << Cell.new(chars[(i + 2)...close].join, strikethrough_style)
            cells << Cell.new("~~", delimiter_style)
            i = close + 2
            next
          end
        end

        plain << chars[i]
        i += 1
      end

      flush.call
      cells
    end

    # First index at/after `from` where `run_len` consecutive copies of
    # `delim` occur, or nil if the opening delimiter never closes — an
    # unterminated `*`/`**`/`~~` degrades to literal text (the `next`
    # fallthrough in #inline_cells) rather than consuming the rest of
    # the line.
    private def find_closing_run(chars : Array(Char), from : Int32, delim : Char, run_len : Int32) : Int32?
      i = from
      while i < chars.size
        if chars[i] == delim
          actual = 0
          while chars[i + actual]? == delim
            actual += 1
          end
          return i if actual >= run_len
          i += actual
        else
          i += 1
        end
      end
      nil
    end
  end
end
