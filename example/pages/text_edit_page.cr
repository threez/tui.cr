require "../../src/tui"

# Seed text demonstrating soft-wrap (the long third paragraph line) and
# the wrap marker, alongside ordinary short lines that need no wrapping.
TEXT_EDIT_SAMPLE = <<-TXT
Scratch pad

Type here — this is a full-screen TextEdit, not a form field, so Enter
always inserts a newline instead of committing.

Long lines soft-wrap at the right edge with a trailing → marker on every
wrapped segment, and a scrollbar appears automatically once your text is
taller than the screen.
TXT

# Builds the "Text editor" demo page: a TextEdit over TEXT_EDIT_SAMPLE,
# hosted in a bordered Window for the scrollbar/title chrome every other
# page already gets for free.
def build_text_edit_page(screen : TUI::Screen) : TUI::Widget
  editor = TUI::TextEdit.new(TEXT_EDIT_SAMPLE)
  editor.focus_if(true)
  TUI::Window.full_screen(screen, editor)
end
