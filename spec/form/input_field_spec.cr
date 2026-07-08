require "../spec_helper"

describe TUI::InputField do
  describe "#cursor_offset" do
    it "lands after the seeded text" do
      editor = TUI::InputField.new
      editor.start("hello")
      editor.cursor_offset.should eq({row: 0, col: 5})
    end

    it "is at col 0 for an empty editor" do
      editor = TUI::InputField.new
      editor.start("")
      editor.cursor_offset.should eq({row: 0, col: 0})
    end

    it "advances by 1 as characters are typed" do
      editor = TUI::InputField.new
      editor.start("")
      editor.handle_key(TUI::KeyEvent.new(TUI::Key::Char, 'h'))
      editor.handle_key(TUI::KeyEvent.new(TUI::Key::Char, 'i'))
      editor.cursor_offset.should eq({row: 0, col: 2})
    end

    it "moves left and right" do
      editor = TUI::InputField.new
      editor.start("hello")
      editor.handle_key(TUI::KeyEvent.new(TUI::Key::Left))
      editor.cursor_offset.should eq({row: 0, col: 4})
      editor.handle_key(TUI::KeyEvent.new(TUI::Key::Right))
      editor.cursor_offset.should eq({row: 0, col: 5})
    end

    it "jumps to Home and End" do
      editor = TUI::InputField.new
      editor.start("hello")
      editor.handle_key(TUI::KeyEvent.new(TUI::Key::Home))
      editor.cursor_offset.should eq({row: 0, col: 0})
      editor.handle_key(TUI::KeyEvent.new(TUI::Key::End))
      editor.cursor_offset.should eq({row: 0, col: 5})
    end
  end

  describe "#handle_key" do
    it "commits on Enter instead of inserting a new line" do
      editor = TUI::InputField.new
      editor.start("hello")

      editor.handle_key(TUI::KeyEvent.new(TUI::Key::Enter)).should eq(:commit)
      editor.value.should eq("hello")
      editor.cursor_offset.should eq({row: 0, col: 5})
    end

    it "commits the typed value intact when Enter is pressed" do
      editor = TUI::InputField.new
      editor.start("")
      editor.handle_key(TUI::KeyEvent.new(TUI::Key::Char, 'h'))
      editor.handle_key(TUI::KeyEvent.new(TUI::Key::Char, 'i'))

      editor.handle_key(TUI::KeyEvent.new(TUI::Key::Enter)).should eq(:commit)
      editor.value.should eq("hi")
    end

    it "commits on Esc without clearing the text" do
      editor = TUI::InputField.new
      editor.start("hello")

      editor.handle_key(TUI::KeyEvent.new(TUI::Key::Esc)).should eq(:commit)
      editor.value.should eq("hello")
    end

    it "backspaces and deletes characters" do
      editor = TUI::InputField.new
      editor.start("hello")
      editor.handle_key(TUI::KeyEvent.new(TUI::Key::Backspace))
      editor.value.should eq("hell")

      editor.handle_key(TUI::KeyEvent.new(TUI::Key::Home))
      editor.handle_key(TUI::KeyEvent.new(TUI::Key::Delete))
      editor.value.should eq("ell")
    end

    it "mentions Enter:commit in its status hint" do
      editor = TUI::InputField.new
      editor.status_hint.should contain("Enter")
      editor.status_hint.should contain("commit")
    end
  end

  describe "#render" do
    it "draws the current text" do
      editor = TUI::InputField.new
      editor.start("hello")
      buffer = TUI::Buffer.new(20, 1)
      editor.render(buffer, 0, 0, 20)

      (0...5).map { |col| buffer.cell(0, col).char }.join.should eq("hello")
    end

    it "scrolls horizontally to keep the cursor visible when text exceeds width" do
      editor = TUI::InputField.new
      editor.start("hello world")
      editor.handle_key(TUI::KeyEvent.new(TUI::Key::End))
      editor.handle_key(TUI::KeyEvent.new(TUI::Key::Left)) # cursor on the final "d", not past it

      buffer = TUI::Buffer.new(5, 1)
      editor.render(buffer, 0, 0, 5)

      (0...5).map { |col| buffer.cell(0, col).char }.join.should eq("world")
    end

    it "does not reverse-video the cursor cell when focused: false" do
      editor = TUI::InputField.new
      editor.start("hi")
      buffer = TUI::Buffer.new(20, 1)
      editor.render(buffer, 0, 0, 20, focused: false)

      (0...2).each { |col| buffer.cell(0, col).style.should eq("") }
    end

    it "reverse-videos the cursor cell when focused: true (default)" do
      editor = TUI::InputField.new
      editor.start("hi")
      buffer = TUI::Buffer.new(20, 1)
      editor.render(buffer, 0, 0, 20)

      buffer.cell(0, 2).style.should contain("7")
    end
  end
end
