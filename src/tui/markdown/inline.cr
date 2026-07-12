require "./inline_run"

module TUI
  module Markdown
    # Scans one line/paragraph's raw text into a flat Array(InlineRun),
    # resolving emphasis (`*`/`_`, doubled and tripled), strikethrough
    # (`~~`, GFM), inline code (backtick-fenced), links (`[text](url)`),
    # and backslash-escapes. Deliberately non-nesting: the first opening
    # delimiter's matching closer ends that span outright, rather than
    # tracking a delimiter stack — covers the overwhelming majority of
    # real-world Markdown while keeping the scanner a single linear
    # left-to-right pass with no backtracking. An opening delimiter with
    # no matching closer anywhere ahead degrades to literal text (emitted
    # as-is) rather than consuming the rest of the line or raising, since
    # a hand-rolled scanner must never hang on malformed input.
    module Inline
      ESCAPABLE = "\\`*_[]~"

      # Bundles the styles inline parsing assigns to each span kind, so a
      # host (MarkdownView) can override them in one place without every
      # Inline.parse call site growing five separate parameters.
      record Config,
        bold_style : Style = Style.new(bold: true),
        italic_style : Style = Style.new(italic: true),
        bold_italic_style : Style = Style.new(bold: true, italic: true),
        strikethrough_style : Style = Style.new(strikethrough: true),
        code_style : Style = Style.new(fg: TUI.color(:yellow)),
        link_style : Style = Style.new(fg: TUI.color(:blue))

      # ameba:disable Metrics/CyclomaticComplexity
      def self.parse(text : String, base_style : Style = Style.new, config : Config = Config.new) : Array(InlineRun)
        runs = [] of InlineRun
        chars = text.chars
        i = 0
        n = chars.size
        plain = String::Builder.new

        flush = -> do
          s = plain.to_s
          runs << InlineRun.new(s, base_style) unless s.empty?
          plain = String::Builder.new
          nil
        end

        while i < n
          ch = chars[i]

          if ch == '\\' && i + 1 < n && ESCAPABLE.includes?(chars[i + 1])
            plain << chars[i + 1]
            i += 2
            next
          end

          if ch == '`'
            close = chars.index('`', i + 1)
            if close
              flush.call
              code_text = chars[(i + 1)...close].join
              runs << InlineRun.new(code_text, config.code_style)
              i = close + 1
              next
            end
            plain << ch
            i += 1
            next
          end

          if ch == '*' || ch == '_'
            run_len = delimiter_run_length(chars, i, ch)
            close_at = find_closing_delimiter(chars, i + run_len, ch, run_len)
            if close_at
              flush.call
              inner_text = chars[(i + run_len)...close_at].join
              style = case run_len
                      when 3 then config.bold_italic_style
                      when 2 then config.bold_style
                      else        config.italic_style
                      end
              runs.concat(parse(inner_text, style, config))
              i = close_at + run_len
              next
            end
            run_len.times { plain << ch }
            i += run_len
            next
          end

          # GFM strikethrough is always exactly `~~`, unlike `*`/`_`
          # emphasis's 1/2/3-run distinction — a single `~` has no
          # special meaning and is left as literal text.
          if ch == '~' && chars[i + 1]? == '~'
            close_at = find_closing_delimiter(chars, i + 2, '~', 2)
            if close_at
              flush.call
              inner_text = chars[(i + 2)...close_at].join
              runs.concat(parse(inner_text, config.strikethrough_style, config))
              i = close_at + 2
              next
            end
          end

          if ch == '['
            link = try_parse_link(chars, i)
            if link
              flush.call
              runs << InlineRun.new("#{link.text} (#{link.url})", config.link_style)
              i = link.next_index
              next
            end
            plain << ch
            i += 1
            next
          end

          plain << ch
          i += 1
        end

        flush.call
        runs
      end

      # How many consecutive copies of `ch` start at `i` (capped at 3 —
      # `***`/`___` is the widest emphasis run this scanner recognizes;
      # a 4th+ consecutive char is treated as literal text belonging to
      # the next token, not a wider delimiter).
      private def self.delimiter_run_length(chars : Array(Char), i : Int32, ch : Char) : Int32
        len = 0
        while len < 3 && i + len < chars.size && chars[i + len] == ch
          len += 1
        end
        len
      end

      # First index at or after `from` where exactly `run_len` consecutive
      # copies of `ch` occur, or nil if none exist before the end of the
      # text — an unterminated opener must be detectable in one forward
      # scan so the caller can fall back to literal text without hanging.
      private def self.find_closing_delimiter(chars : Array(Char), from : Int32, ch : Char, run_len : Int32) : Int32?
        i = from
        n = chars.size
        while i < n
          if chars[i] == ch
            actual = delimiter_run_length(chars, i, ch)
            return i if actual >= run_len
            i += actual
          else
            i += 1
          end
        end
        nil
      end

      private record LinkMatch, text : String, url : String, next_index : Int32

      # Recognizes `[text](url)` starting at `chars[i] == '['`. Returns
      # nil (falling back to literal `[`) if the brackets/parens don't
      # close on the same line — links spanning a hard line break aren't
      # supported, matching this scanner's line-at-a-time operation.
      private def self.try_parse_link(chars : Array(Char), i : Int32) : LinkMatch?
        text_close = chars.index(']', i + 1)
        return nil unless text_close
        return nil unless chars[text_close + 1]? == '('
        url_close = chars.index(')', text_close + 2)
        return nil unless url_close

        text = chars[(i + 1)...text_close].join
        url = chars[(text_close + 2)...url_close].join
        LinkMatch.new(text, url, url_close + 1)
      end
    end
  end
end
