require "../../src/tui"
require "../data"

# Builds the "Split window" demo page: one bordered box, two independent
# TableViews (packages | formulas) side by side. Tab-toggle and the
# shared border are handled entirely by SplitWindow itself.
def build_split_page(screen : TUI::Screen) : TUI::Widget
  left = TUI::TableView.new(build_package_source)
  right = TUI::TableView.new(build_formula_source)

  split = TUI::SplitWindow.full_screen(screen, left, right)
  split.border_style = TUI::Style.new(fg: TUI.color(:magenta))
  split
end
