require "../../src/tui"

MENU_ENTRIES = ["Table view", "Split window", "H-split layout", "Edit package", "Markdown viewer", "Text editor"]

# Builds the root "Widget browser" menu: a static OptionListView over
# MENU_ENTRIES, hosted in a Window for the border/scrollbar/highlight
# chrome every other page already gets for free. `wire_value` is each
# entry's original array index (as a string) rather than the label, so
# `on_open` gets called with a stable index even if the list is ever
# filtered — OptionListView#on_activate's index is only meaningful
# against the currently filtered list, never the original array.
def build_menu_page(screen : TUI::Screen, on_open : Proc(Int32, Nil)) : TUI::Widget
  options = MENU_ENTRIES.each_with_index.map { |label, i| TUI::FormEnumOption.new(label, i.to_s) }.to_a
  source = TUI::OptionListSource.new("Widget browser", options)
  list = TUI::OptionListView.new(source)
  list.reload
  list.on_activate = ->(index : Int32) {
    on_open.call(source.option_at(index).wire_value.to_i)
    nil
  }

  TUI::Window.full_screen(screen, list)
end
