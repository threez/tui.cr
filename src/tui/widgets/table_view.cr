require "./list_view"
require "./list_view_define"
require "./cell"
require "../data_sources/table_data_source"

module TUI
  class TableView < ListView
    scroll header: 1

    # Applied to the header row's text (see #render_header).
    property header_style : Style = Style.new(bold: true)

    def initialize(@table_source : TableDataSource)
      super(@table_source)
      @col_widths = [] of Int32
      reload
    end

    protected def render_header(buffer : Buffer) : Nil
      col_defs = @table_source.columns
      # Reserve the 2-char leading prefix every row carries (header:
      # "  "; data: " " + pointer glyph) plus one separator space between
      # each pair of columns, so the joined row never exceeds buffer.width.
      available = buffer.width - 2 - [col_defs.size - 1, 0].max
      @col_widths = compute_col_widths(col_defs, available)

      # Header row (leading 2 spaces align with the 1-char pointer column + separator in data rows)
      hdr = col_defs.each_with_index.map { |col_def, index| Term.apply(header_style, Term.fit(col_def.header, @col_widths[index], col_def.align)) }.join(" ")
      buffer.set(0, 0, "  #{hdr}")
    end

    def row_content(index : Int32) : String
      col_defs = @table_source.columns
      r = @table_source.row(index)
      col_defs.each_with_index.map do |col_def, col_index|
        cell = r.cells[col_index]? || Cell.new("")
        fitted = Term.fit(cell.text, @col_widths[col_index], col_def.align)
        CellStyle.apply(cell.style, fitted)
      end.join(" ")
    end

    private def compute_col_widths(col_defs : Array(TableColumn), available : Int32) : Array(Int32)
      n = col_defs.size
      return [] of Int32 if n == 0

      # Start every column at its preferred (natural/max) width.
      widths = col_defs.map(&.preferred_width)
      total = widths.sum

      if total > available
        # Not enough room even at preferred widths — shrink everything down
        # to min_width, then hand back proportionally to how much slack each
        # column had above its floor.
        widths = col_defs.map(&.min_width)
        used = widths.sum
        extra = [available - used, 0].max
        shrinkable_total = col_defs.sum { |col_def| [col_def.preferred_width - col_def.min_width, 0].max }
        if shrinkable_total > 0
          col_defs.each_with_index do |col_def, index|
            room = [col_def.preferred_width - col_def.min_width, 0].max
            widths[index] += (extra * room / shrinkable_total).to_i
          end
        end
      else
        slack = available - total
        expanding = col_defs.each_with_index.select { |col_def, _| col_def.expand }.to_a
        if slack > 0 && !expanding.empty?
          total_pref = expanding.sum { |col_def, _| col_def.preferred_width }.to_f
          expanding.each do |col_def, index|
            share = total_pref > 0 ? (slack * col_def.preferred_width / total_pref) : (slack / expanding.size)
            widths[index] += share.to_i
          end
          # Give rounding remainder to the last expanding column
          last_idx = expanding.last[1]
          widths[last_idx] = [available - (widths.sum - widths[last_idx]), col_defs[last_idx].min_width].max
        end
      end

      widths
    end
  end
end
