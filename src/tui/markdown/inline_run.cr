module TUI
  module Markdown
    # One contiguous span of same-styled inline text, e.g. a word or run
    # of words that share emphasis/code/link styling. Produced by
    # Inline.parse, consumed by Wrap.wrap — text is never re-split across
    # a style boundary, so a wrap point can only ever fall between runs
    # or inside whitespace within a run, never inside a styled word.
    record InlineRun, text : String, style : Style = Style.new
  end
end
