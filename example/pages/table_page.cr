require "../../src/tui"
require "../data"
require "./detail_page"

# Builds the "Table view" demo page: a TableView over fake package data,
# double-clicking a row opens a reused DetailView Window pushed on top.
def build_table_page(screen : TUI::Screen, runtime : TUI::Runtime) : TUI::Widget
  table_source = build_package_source
  table = TUI::TableView.new(table_source)

  detail_page = build_detail_page(screen, PACKAGE_DETAIL_SOURCE)

  table.on_activate = ->(index : Int32) {
    detail_page[:detail].load(table_source.item_at(index).name)
    detail_page[:window].reset_scroll
    runtime.push(detail_page[:window].as(TUI::Widget))
    nil
  }

  window = TUI::Window.full_screen(screen, table)
  window.border_style = TUI::Style.new(fg: TUI.color(:blue))
  window
end
