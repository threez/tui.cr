require "./block"
require "./inline"

module TUI
  module Markdown
    # Hand-rolled line-oriented block parser: walks the source a line at
    # a time with a cursor, dispatching on each line's leading shape into
    # a flat Array(Block). No external Markdown shard is used (shard.yml
    # has zero runtime dependencies) — this recognizes the subset of
    # CommonMark/GFM documented as in-scope on MarkdownView.
    module Parser
      HRULE            = /^ {0,3}([-*_])( *\1){2,} *$/
      ATX_HEADING      = /^ {0,3}(\#{1,6})\s+(.*?)\s*\#*\s*$/
      FENCE_OPEN       = /^ {0,3}(```|~~~)\s*(\S*)\s*$/
      BLOCKQUOTE       = /^ {0,3}(>+)\s?(.*)$/
      UNORDERED_ITEM   = /^( *)([-*+])\s+(.*)$/
      ORDERED_ITEM     = /^( *)(\d+)[.)]\s+(.*)$/
      TASK_PREFIX      = /^\[([ xX])\]\s+(.*)$/
      TABLE_ROW        = /\|/
      TABLE_DELIM_CELL = /^:?-+:?$/

      def self.parse(source : String, number_headings : Bool = true, inline_config : Inline::Config = Inline::Config.new) : Array(Block)
        lines = source.gsub("\r\n", "\n").split("\n")
        blocks = [] of Block
        counters = [0, 0, 0, 0, 0, 0]
        i = 0
        n = lines.size

        while i < n
          line = lines[i]

          if line.strip.empty?
            i += 1
            next
          end

          if line =~ HRULE
            blocks << HRule.new
            i += 1
            next
          end

          if m = ATX_HEADING.match(line)
            level = m[1].size
            title = m[2]
            number = number_headings ? heading_number(counters, level) : ""
            blocks << Heading.new(level, number, Inline.parse(title, config: inline_config))
            i += 1
            next
          end

          if m = FENCE_OPEN.match(line)
            fence = m[1]
            language = m[2].empty? ? nil : m[2]
            code_lines = [] of String
            i += 1
            while i < n && !(lines[i].strip.starts_with?(fence))
              code_lines << lines[i]
              i += 1
            end
            i += 1 if i < n # consume closing fence
            blocks << CodeBlock.new(code_lines, language)
            next
          end

          if m = BLOCKQUOTE.match(line)
            depth = m[1].size
            quote_lines = [] of String
            while i < n && (bm = BLOCKQUOTE.match(lines[i])) && bm[1].size == depth
              quote_lines << bm[2]
              i += 1
            end
            blocks << Blockquote.new(depth, Inline.parse(quote_lines.join(" "), config: inline_config))
            next
          end

          if looks_like_table_header?(lines, i)
            table, consumed = parse_table(lines, i, inline_config)
            blocks << table
            i += consumed
            next
          end

          if UNORDERED_ITEM.matches?(line) || ORDERED_ITEM.matches?(line)
            list, consumed = parse_list(lines, i, inline_config)
            blocks << list
            i += consumed
            next
          end

          # Paragraph: consume lines until a blank line or the start of
          # another block type, joining with a space (a single newline
          # inside a paragraph is a soft break, collapsed to a space,
          # matching standard Markdown reflow semantics).
          para_lines = [] of String
          while i < n && !lines[i].strip.empty? && !starts_new_block?(lines[i])
            para_lines << lines[i].strip
            i += 1
          end
          blocks << Paragraph.new(Inline.parse(para_lines.join(" "), config: inline_config))
        end

        blocks
      end

      # Nested-outline numbering: increment this level's counter, reset
      # every strictly-deeper counter to 0, then join every non-zero
      # ancestor counter with ".". Computed once here (not at render
      # time) so it can never skew when the document is re-wrapped at a
      # different width.
      private def self.heading_number(counters : Array(Int32), level : Int32) : String
        counters[level - 1] += 1
        (level..5).each { |i| counters[i] = 0 }
        counters[0...level].reject(&.zero?).join(".")
      end

      private def self.starts_new_block?(line : String) : Bool
        HRULE.matches?(line) || ATX_HEADING.matches?(line) || FENCE_OPEN.matches?(line) ||
          BLOCKQUOTE.matches?(line) || UNORDERED_ITEM.matches?(line) || ORDERED_ITEM.matches?(line)
      end

      # A table needs its header row followed immediately by a delimiter
      # row shaped like `|---|:---:|---:|` — checked via lookahead so a
      # bare line containing "|" that ISN'T a table (e.g. a sentence
      # mentioning a pipe) doesn't get misdetected.
      private def self.looks_like_table_header?(lines : Array(String), i : Int32) : Bool
        return false unless i + 1 < lines.size
        return false unless lines[i] =~ TABLE_ROW
        delim_cells = split_table_row(lines[i + 1])
        return false if delim_cells.empty?
        delim_cells.all? { |cell| TABLE_DELIM_CELL.matches?(cell.strip) }
      end

      private def self.split_table_row(line : String) : Array(String)
        trimmed = line.strip
        trimmed = trimmed[1..]? || "" if trimmed.starts_with?("|")
        trimmed = trimmed[0...-1] if trimmed.ends_with?("|")
        trimmed.split("|").map(&.strip)
      end

      private def self.cell_align(delim_cell : String) : Align
        c = delim_cell.strip
        left = c.starts_with?(":")
        right = c.ends_with?(":")
        return Align::Center if left && right
        return Align::Right if right
        Align::Left
      end

      private def self.parse_table(lines : Array(String), start : Int32, inline_config : Inline::Config) : {Table, Int32}
        header_cells = split_table_row(lines[start]).map { |cell| Inline.parse(cell, config: inline_config) }
        aligns = split_table_row(lines[start + 1]).map { |cell| cell_align(cell) }

        rows = [] of Array(Array(InlineRun))
        i = start + 2
        while i < lines.size && lines[i] =~ TABLE_ROW && !lines[i].strip.empty?
          rows << split_table_row(lines[i]).map { |cell| Inline.parse(cell, config: inline_config) }
          i += 1
        end

        {Table.new(header_cells, rows, aligns), i - start}
      end

      # Consumes every contiguous list-item line (any depth/marker kind)
      # starting at `start` into one ListBlock. Depth is derived from
      # each line's leading-whitespace column count divided by 2 (a
      # depth-1 nested item is conventionally indented 2+ spaces under
      # its parent marker) rather than requiring exact alignment, so
      # slightly-uneven source indentation still nests sensibly. Ordered
      # items are renumbered per this list (source numbers ignored
      # beyond "is this ordered"), matching CommonMark's actual-number-
      # only-matters-for-the-first-item convention.
      private def self.parse_list(lines : Array(String), start : Int32, inline_config : Inline::Config) : {ListBlock, Int32}
        items = [] of ListItem
        ordered_counters = Hash(Int32, Int32).new(0)
        i = start

        while i < lines.size
          line = lines[i]
          break if line.strip.empty?

          if m = UNORDERED_ITEM.match(line)
            indent = m[1].size
            depth = indent // 2
            checked = task_checked(m[3])
            body = checked.nil? ? m[3] : (TASK_PREFIX.match(m[3]).try(&.[2]) || m[3])
            items << ListItem.new(Inline.parse(body, config: inline_config), depth, false, nil, checked)
            i += 1
          elsif m = ORDERED_ITEM.match(line)
            indent = m[1].size
            depth = indent // 2
            ordered_counters[depth] += 1
            items << ListItem.new(Inline.parse(m[3], config: inline_config), depth, true, ordered_counters[depth], nil)
            i += 1
          else
            break
          end
        end

        {ListBlock.new(items), i - start}
      end

      private def self.task_checked(item_text : String) : Bool?
        m = TASK_PREFIX.match(item_text)
        return nil unless m
        state = m[1]
        state == "x" || state == "X"
      end
    end
  end
end
