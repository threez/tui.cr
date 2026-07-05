require "../../src/tui"
require "../data"

# Builds the "H-split layout" demo page: two borderless Windows
# (packages | formulas) placed side by side via HSplit's single plain
# divider, contrasted with SplitWindow's shared bordered-box style.
# HSplit itself owns Tab-toggling the active pane and routing keys to
# it, the same convention SplitWindow uses for its Scrollables.
def build_hsplit_page(screen : TUI::Screen) : TUI::Widget
  left_table = TUI::TableView.new(build_package_source)
  right_table = TUI::TableView.new(build_formula_source)

  hsplit = TUI::HSplit.full_screen_scrollables(screen, left_table, right_table)
  hsplit.border_style = TUI::Style.new(fg: TUI.color(:cyan))
  hsplit
end
