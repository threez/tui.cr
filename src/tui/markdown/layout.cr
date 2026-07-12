require "./block"
require "./wrap"

module TUI
  module Markdown
    # Turns a width-agnostic Array(Block) into flattened physical rows —
    # one Array(InlineRun) per row actually drawn to the screen — by
    # applying block-specific indent/marker/border rules and running
    # Wrap.wrap wherever reflow is appropriate (paragraphs, list items,
    # blockquotes; NOT code blocks, which stay verbatim since rewrapping
    # code would change its meaning; NOT table cells, which truncate
    # instead — see Config#table_max_col_width).
    module Layout
      # Bundles every MarkdownView style/spacing property Layout needs.
      # Layout itself holds no state — it's a pure function of
      # (blocks, width, config) — so this is just a parameter-passing
      # convenience, not a second source of truth for defaults (those
      # live on MarkdownView; Config's defaults here exist only so
      # Layout is independently spec-able without constructing a view).
      record Config,
        heading_styles : Array(Style) = [
          Style.new(bold: true, fg: TUI.color(:cyan)),
          Style.new(bold: true),
          Style.new(bold: true, dim: true),
          Style.new(dim: true),
          Style.new(dim: true),
          Style.new(dim: true),
        ],
        heading_indent_step : Int32 = 2,
        list_marker_style : Style = Style.new(fg: TUI.color(:gray)),
        list_indent_step : Int32 = 3,
        list_bullet_glyphs : Array(String) = ["•", "◦", "▪"],
        quote_style : Style = Style.new(fg: TUI.color(:gray), dim: true),
        quote_indent_step : Int32 = 2,
        table_border_style : Style = Style.new(fg: TUI.color(:gray)),
        table_header_style : Style = Style.new(bold: true),
        hrule_style : Style = Style.new(fg: TUI.color(:gray)),
        table_max_col_width : Int32 = 40,
        table_min_col_width : Int32 = 3

      def self.layout(blocks : Array(Block), width : Int32, config : Config = Config.new) : Array(Array(InlineRun))
        rows = [] of Array(InlineRun)
        width = [width, 1].max

        blocks.each_with_index do |block, i|
          rows << [] of InlineRun if i > 0 && needs_blank_separator?(blocks[i - 1], block)

          case block
          when Heading
            layout_heading(rows, block, width, config)
          when Paragraph
            Wrap.wrap(block.runs, width).each { |line| rows << line }
          when CodeBlock
            layout_code_block(rows, block)
          when Blockquote
            layout_blockquote(rows, block, width, config)
          when ListBlock
            layout_list(rows, block, width, config)
          when HRule
            rows << [InlineRun.new(Term::HL * width, config.hrule_style)]
          when Table
            layout_table(rows, block, width, config)
          end
        end

        rows
      end

      # A blank row of visual separation between two blocks, except when
      # the previous block was already a heading immediately followed by
      # its own content (avoids doubled gaps stacking up).
      private def self.needs_blank_separator?(prev : Block, cur : Block) : Bool
        !(prev.is_a?(Heading) && cur.is_a?(Heading))
      end

      private def self.layout_heading(rows : Array(Array(InlineRun)), heading : Heading, width : Int32, config : Config) : Nil
        indent = (heading.level - 1) * config.heading_indent_step
        style = config.heading_styles[[heading.level - 1, config.heading_styles.size - 1].min]
        prefix = heading.number.empty? ? "" : "#{heading.number}  "
        title_runs = heading.runs.map { |run| InlineRun.new(run.text, style) }

        wrapped = Wrap.wrap(title_runs, [width - indent, 1].max)
        wrapped.each_with_index do |line, i|
          leading = i == 0 ? prefix : "#{" " * prefix.size}"
          full_line = [InlineRun.new(" " * indent, Style.new)] of InlineRun
          full_line << InlineRun.new(leading, style) unless leading.empty?
          full_line.concat(line)
          rows << full_line
        end
      end

      private def self.layout_code_block(rows : Array(Array(InlineRun)), block : CodeBlock) : Nil
        style = Style.new(fg: TUI.color(:yellow), dim: true)
        # block.lines is Array(String), not String — each_line doesn't apply here.
        block.lines.each do |line| # ameba:disable Performance/ExcessiveAllocations
          rows << [InlineRun.new(line, style)]
        end
      end

      private def self.layout_blockquote(rows : Array(Array(InlineRun)), block : Blockquote, width : Int32, config : Config) : Nil
        bar = "#{Term::VL} " * block.depth
        avail = [width - bar.size, 1].max
        wrapped = Wrap.wrap(block.runs, avail)
        wrapped.each do |line|
          full_line = [InlineRun.new(bar, config.quote_style)] of InlineRun
          full_line.concat(line)
          rows << full_line
        end
      end

      private def self.layout_list(rows : Array(Array(InlineRun)), block : ListBlock, width : Int32, config : Config) : Nil
        marker_width = block.items.max_of? { |item| marker_text(item, block.items).size } || 0

        block.items.each do |item|
          indent = item.depth * config.list_indent_step
          marker = marker_text(item, block.items)
          text_col = indent + marker_width + 1
          avail = [width - text_col, 1].max

          wrapped = Wrap.wrap(item.runs, avail)
          wrapped.each_with_index do |line, i|
            full_line = [] of InlineRun
            if i == 0
              full_line << InlineRun.new(" " * indent, Style.new)
              full_line << InlineRun.new(marker.ljust(marker_width), config.list_marker_style)
              full_line << InlineRun.new(" ", Style.new)
            else
              full_line << InlineRun.new(" " * text_col, Style.new)
            end
            full_line.concat(line)
            rows << full_line
          end
        end
      end

      private def self.marker_text(item : ListItem, siblings : Array(ListItem)) : String
        return "#{item.checked ? "☑" : "☐"}" unless item.checked.nil?
        return "#{item.index}." if item.ordered?
        glyphs = ["•", "◦", "▪"]
        glyphs[item.depth % glyphs.size]
      end

      private def self.layout_table(rows : Array(Array(InlineRun)), table : Table, width : Int32, config : Config) : Nil
        n = table.header.size
        return if n == 0

        col_widths = compute_col_widths(table, width, config)
        padded_widths = col_widths.map { |col_width| col_width + 2 }

        rows << [InlineRun.new(Term.border_line(padded_widths, Term::TL, Term::HL, Term::TJ, Term::TR), config.table_border_style)]
        rows << table_row(table.header, table.aligns, col_widths, config.table_header_style, config)
        rows << [InlineRun.new(Term.border_line(padded_widths, Term::LJ, Term::HL, Term::CJ, Term::RJ), config.table_border_style)]
        table.rows.each do |row|
          rows << table_row(row, table.aligns, col_widths, Style.new, config)
        end
        rows << [InlineRun.new(Term.border_line(padded_widths, Term::BL, Term::HL, Term::BJ, Term::BR), config.table_border_style)]
      end

      private def self.table_row(cells : Array(Array(InlineRun)), aligns : Array(Align), col_widths : Array(Int32), cell_style : Style, config : Config) : Array(InlineRun)
        runs = [] of InlineRun
        runs << InlineRun.new(Term::VL, config.table_border_style)
        col_widths.each_with_index do |col_width, i|
          text = (cells[i]? || [] of InlineRun).map(&.text).join
          align = aligns[i]? || Align::Left
          fitted = Term.fit(text, col_width, align)
          runs << InlineRun.new(" ", Style.new)
          runs << InlineRun.new(fitted, cell_style)
          runs << InlineRun.new(" ", Style.new)
          runs << InlineRun.new(Term::VL, config.table_border_style)
        end
        runs
      end

      private def self.compute_col_widths(table : Table, width : Int32, config : Config) : Array(Int32)
        n = table.header.size
        natural = (0...n).map do |col|
          cells = [table.header[col]] + table.rows.map { |row| row[col]? || [] of InlineRun }
          natural_width = cells.max_of?(&.map(&.text).join.size) || 1
          [[natural_width, 1].max, config.table_max_col_width].min
        end

        total = natural.sum
        border_overhead = 1 + n + (n - 1) + 2 * n
        budget = [width - border_overhead, n * config.table_min_col_width].max

        if total <= budget
          slack = budget - total
          widths = natural.dup
          if slack > 0 && total > 0
            natural.each_with_index do |natural_width, i|
              widths[i] += (slack * natural_width / total.to_f).to_i
            end
            widths[-1] = budget - widths[0...-1].sum
          end
          widths
        else
          widths = natural.map { |natural_width| [(budget * natural_width / total.to_f).to_i, config.table_min_col_width].max }
          widths[-1] = [budget - widths[0...-1].sum, config.table_min_col_width].max
          widths
        end
      end
    end
  end
end
