require "../spec_helper"

describe TUI::BoolField do
  it "starts false for anything other than the literal string 'true'" do
    editor = TUI::BoolField.new
    editor.start("false")
    editor.value.should eq("false")
  end

  it "starts true for the literal string 'true'" do
    editor = TUI::BoolField.new
    editor.start("true")
    editor.value.should eq("true")
  end

  it "toggles with Left/Right and Space, and commits on Enter/Esc" do
    editor = TUI::BoolField.new
    editor.start("false")
    editor.handle_key(TUI::KeyEvent.new(TUI::Key::Right))
    editor.value.should eq("true")
    editor.handle_key(TUI::KeyEvent.new(TUI::Key::Char, ' '))
    editor.value.should eq("false")
    editor.handle_key(TUI::KeyEvent.new(TUI::Key::Enter)).should eq(:commit)
  end
end
