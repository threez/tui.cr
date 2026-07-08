require "../../src/tui"

# Reuses MARKDOWN_SAMPLE (defined in markdown_page.cr) so the read-only
# MarkdownView and the editable MarkdownEdit demo the same document —
# letting a reader compare the two side by side (well, page by page)
# instead of comparing highlighting against unrelated sample text.
def build_markdown_edit_page(screen : TUI::Screen) : TUI::Widget
  editor = TUI::MarkdownEdit.new(MARKDOWN_SAMPLE)
  editor.focus_if(true)
  TUI::Window.full_screen(screen, editor)
end
