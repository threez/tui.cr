require "../widgets/cell"
require "./list_data_source"

module TUI
  # One column definition, driving TableView's layout (see
  # TableView#compute_col_widths). Columns start at `preferred_width`; if
  # the available width is too small they shrink toward `min_width`
  # (proportionally to slack above the floor); if there's width to spare,
  # only columns with `expand` true grow to fill it, split proportionally
  # to their own `preferred_width`. `align` controls Term.fit's padding
  # side for both header and cell text.
  record TableColumn,
    header : String,
    min_width : Int32,
    preferred_width : Int32,
    expand : Bool = false,
    align : Align = Align::Left

  # One data row: styled Cells in the same order as TableDataSource#columns.
  # A row shorter than the column count renders missing cells as blank
  # (see TableView#row_content); it is never an error to omit trailing cells.
  record TableRow,
    cells : Array(Cell) = [] of Cell

  abstract class TableDataSource < ListDataSource
    abstract def columns : Array(TableColumn)
    abstract def row(index : Int32) : TableRow
  end
end
