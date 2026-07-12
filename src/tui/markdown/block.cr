require "./inline_run"

module TUI
  module Markdown
    # A parsed, width-agnostic Markdown document element. Block.parse
    # produces a flat Array(Block) — nesting (e.g. a list's items, a
    # blockquote's depth) is captured as data on the node itself
    # (ListItem#depth, Blockquote#depth) rather than as a tree, since
    # Layout.layout only ever needs to walk the array once in order.
    abstract class Block
    end

    # `number` is the precomputed nested-outline numbering string (e.g.
    # "1.2.3"), computed once at parse time by Parser so it can never
    # skew on rewrap — "" when Parser was configured not to number
    # headings, in which case Layout renders no number prefix at all.
    class Heading < Block
      property level : Int32
      property number : String
      property runs : Array(InlineRun)

      def initialize(@level : Int32, @number : String, @runs : Array(InlineRun))
      end
    end

    class Paragraph < Block
      property runs : Array(InlineRun)

      def initialize(@runs : Array(InlineRun))
      end
    end

    # Lines are kept verbatim (not inline-parsed) — code shouldn't be
    # subject to emphasis scanning or word-wrap, since either would
    # change its meaning.
    class CodeBlock < Block
      property lines : Array(String)
      property language : String?

      def initialize(@lines : Array(String), @language : String? = nil)
      end
    end

    class Blockquote < Block
      property depth : Int32
      property runs : Array(InlineRun)

      def initialize(@depth : Int32, @runs : Array(InlineRun))
      end
    end

    # `index` is the rendered ordinal for an ordered item (renumbered
    # per rendered list, not the source's own numbers — see Parser);
    # nil for an unordered item. `checked` is nil for a plain list item,
    # true/false for a GFM task-list item ("- [x]"/"- [ ]").
    class ListItem
      property runs : Array(InlineRun)
      property depth : Int32
      property? ordered : Bool
      property index : Int32?
      property checked : Bool?

      def initialize(@runs : Array(InlineRun), @depth : Int32, @ordered : Bool,
                     @index : Int32? = nil, @checked : Bool? = nil)
      end
    end

    class ListBlock < Block
      property items : Array(ListItem)

      def initialize(@items : Array(ListItem))
      end
    end

    class HRule < Block
    end

    # `header`/`rows` cells are already inline-parsed (a cell may itself
    # carry emphasis/code styling); `aligns` reuses the existing Align
    # enum (term.cr) rather than inventing a parallel one.
    class Table < Block
      property header : Array(Array(InlineRun))
      property rows : Array(Array(Array(InlineRun)))
      property aligns : Array(Align)

      def initialize(@header : Array(Array(InlineRun)), @rows : Array(Array(Array(InlineRun))), @aligns : Array(Align))
      end
    end
  end
end
