require "../spec_helper"

describe TUI::FlagsField do
  it "decodes the seeded bitmask into the selected set" do
    options = [TUI::FormEnumOption.new("A", "a"), TUI::FormEnumOption.new("B", "b")]
    editor = TUI::FlagsField.new(options)
    editor.start("1") # bit 0 set -> "A" selected
    editor.value.should eq("1")
  end

  it "toggles the focused option with Space, independent of Up/Down" do
    options = [TUI::FormEnumOption.new("A", "a"), TUI::FormEnumOption.new("B", "b")]
    editor = TUI::FlagsField.new(options)
    editor.start("0")
    editor.handle_key(TUI::KeyEvent.new(TUI::Key::Down))
    editor.handle_key(TUI::KeyEvent.new(TUI::Key::Char, ' '))
    editor.value.should eq("2") # bit 1 ("B") set
  end

  describe "#render" do
    it "does not reverse-video the keyboard-cursor row when focused: false" do
      options = [TUI::FormEnumOption.new("A", "a"), TUI::FormEnumOption.new("B", "b")]
      editor = TUI::FlagsField.new(options)
      editor.start("1") # selects index 0 ("A"); @focus_index defaults to 0 regardless
      buffer = TUI::Buffer.new(20, 5)
      editor.render(buffer, 0, 0, 20, height: 2, focused: false)

      buffer.cell(0, 0).style.should eq("")
      buffer.cell(1, 0).style.should eq("")
    end

    it "reverse-videos the keyboard-cursor row when focused: true (default)" do
      options = [TUI::FormEnumOption.new("A", "a"), TUI::FormEnumOption.new("B", "b")]
      editor = TUI::FlagsField.new(options)
      editor.start("1")
      buffer = TUI::Buffer.new(20, 5)
      editor.render(buffer, 0, 0, 20, height: 2)

      buffer.cell(0, 0).style.should contain("7")
    end
  end
end
