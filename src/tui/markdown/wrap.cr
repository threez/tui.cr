require "./inline_run"

module TUI
  module Markdown
    # Pure greedy word-wrap over a sequence of styled InlineRuns — no
    # dependency on Buffer/Term/the parser, so it's spec'd as a standalone
    # function. Breaks only at whitespace boundaries; a single word wider
    # than `width` is hard-broken into width-sized chunks (better than
    # overflowing the buffer). Styling is preserved per run across a wrap
    # point: a run is never merged with a NEIGHBORING run of a different
    # style, so a bold word can never bleed its style onto adjacent plain
    # text regardless of where the line happens to break.
    module Wrap
      private record Token, text : String, style : Style, space : Bool

      def self.wrap(runs : Array(InlineRun), width : Int32) : Array(Array(InlineRun))
        width = [width, 1].max
        tokens = tokenize(runs)

        lines = [[] of InlineRun]
        col = 0

        tokens.each do |tok|
          if tok.space
            next if col == 0
            if col + tok.text.size > width
              lines << [] of InlineRun
              col = 0
            else
              append(lines, tok.text, tok.style)
              col += tok.text.size
            end
            next
          end

          word_w = tok.text.size

          if col > 0 && col + word_w > width
            lines << [] of InlineRun
            col = 0
          end

          if word_w > width
            pos = 0
            while pos < tok.text.size
              chunk = tok.text[pos, width]
              append(lines, chunk, tok.style)
              pos += width
              if pos < tok.text.size
                lines << [] of InlineRun
                col = 0
              else
                col = chunk.size
              end
            end
          else
            append(lines, tok.text, tok.style)
            col += word_w
          end
        end

        lines.pop if lines.size > 1 && lines.last.empty?
        lines
      end

      private def self.tokenize(runs : Array(InlineRun)) : Array(Token)
        tokens = [] of Token
        runs.each do |run|
          run.text.scan(/(\s+)|(\S+)/) do |m|
            if space = m[1]?
              tokens << Token.new(space, run.style, true)
            elsif word = m[2]?
              tokens << Token.new(word, run.style, false)
            end
          end
        end
        tokens
      end

      private def self.append(lines : Array(Array(InlineRun)), text : String, style : Style) : Nil
        cur = lines.last
        if !cur.empty? && cur.last.style == style
          cur[-1] = InlineRun.new(cur.last.text + text, style)
        else
          cur << InlineRun.new(text, style)
        end
      end
    end
  end
end
