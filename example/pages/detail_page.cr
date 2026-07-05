require "../../src/tui"
require "../data"

# Builds the single, reused DetailView + hosting Window for the table
# page's drill-down. Held by table_page.cr across activations — callers
# should call `detail.load(id)` then `window.reset_scroll` before each
# `runtime.push(window)`, per DetailView#load's documented contract.
def build_detail_page(screen : TUI::Screen, source : TUI::ArrayDetailSource(Package)) : {detail: TUI::DetailView, window: TUI::Window}
  detail = TUI::DetailView.new(source)
  window = TUI::Window.full_screen(screen, detail)
  window.border_style = TUI::Style.new(fg: TUI.color(:green))
  {detail: detail, window: window}
end
