require "../spec_helper"

describe TUI::EnumField do
  it "selects the option matching the seeded wire value" do
    options = [TUI::FormEnumOption.new("A", "a"), TUI::FormEnumOption.new("B", "b")]
    editor = TUI::EnumField.new(options)
    editor.start("b")
    editor.value.should eq("b")
  end

  it "moves the selection with Up/Down, clamped to the option range" do
    options = [TUI::FormEnumOption.new("A", "a"), TUI::FormEnumOption.new("B", "b")]
    editor = TUI::EnumField.new(options)
    editor.start("a")
    editor.handle_key(TUI::KeyEvent.new(TUI::Key::Down))
    editor.value.should eq("b")
    editor.handle_key(TUI::KeyEvent.new(TUI::Key::Down))
    editor.value.should eq("b") # clamped, no third option
  end

  it "cancels on Esc, commits on Enter" do
    options = [TUI::FormEnumOption.new("A", "a"), TUI::FormEnumOption.new("B", "b")]
    editor = TUI::EnumField.new(options)
    editor.start("a")
    editor.handle_key(TUI::KeyEvent.new(TUI::Key::Esc)).should eq(:cancel)
    editor.handle_key(TUI::KeyEvent.new(TUI::Key::Enter)).should eq(:commit)
  end
end
