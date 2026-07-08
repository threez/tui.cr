require "../spec_helper"

describe TUI::TextField do
  describe "#cursor_offset" do
    it "lands after the seeded text" do
      editor = TUI::TextField.new
      editor.start("hello")
      editor.cursor_offset.should eq({row: 0, col: 5})
    end

    it "is at col 0 for an empty editor" do
      editor = TUI::TextField.new
      editor.start("")
      editor.cursor_offset.should eq({row: 0, col: 0})
    end

    it "advances by 1 as characters are typed" do
      editor = TUI::TextField.new
      editor.start("")
      editor.handle_key(TUI::KeyEvent.new(TUI::Key::Char, 'h'))
      editor.handle_key(TUI::KeyEvent.new(TUI::Key::Char, 'i'))
      editor.cursor_offset.should eq({row: 0, col: 2})
    end

    it "moves left and right" do
      editor = TUI::TextField.new
      editor.start("hello")
      editor.handle_key(TUI::KeyEvent.new(TUI::Key::Left))
      editor.cursor_offset.should eq({row: 0, col: 4})
      editor.handle_key(TUI::KeyEvent.new(TUI::Key::Right))
      editor.cursor_offset.should eq({row: 0, col: 5})
    end

    it "jumps to Home and End" do
      editor = TUI::TextField.new
      editor.start("hello")
      editor.handle_key(TUI::KeyEvent.new(TUI::Key::Home))
      editor.cursor_offset.should eq({row: 0, col: 0})
      editor.handle_key(TUI::KeyEvent.new(TUI::Key::End))
      editor.cursor_offset.should eq({row: 0, col: 5})
    end

    it "moves to row 1, col 0 on a new line after Enter" do
      editor = TUI::TextField.new
      editor.start("hello")
      editor.handle_key(TUI::KeyEvent.new(TUI::Key::Enter))
      editor.cursor_offset.should eq({row: 1, col: 0})
    end

    it "tracks the correct row across lines with Up/Down" do
      editor = TUI::TextField.new
      editor.start("hello")
      editor.handle_key(TUI::KeyEvent.new(TUI::Key::Enter))
      editor.handle_key(TUI::KeyEvent.new(TUI::Key::Char, 'x'))
      editor.cursor_offset.should eq({row: 1, col: 1})

      editor.handle_key(TUI::KeyEvent.new(TUI::Key::Up))
      editor.cursor_offset[:row].should eq(0)

      editor.handle_key(TUI::KeyEvent.new(TUI::Key::Down))
      editor.cursor_offset[:row].should eq(1)
    end
  end

  describe "single-line mode (multiline: false)" do
    it "commits on Enter instead of inserting a new line" do
      editor = TUI::TextField.new(multiline: false)
      editor.start("hello")

      editor.handle_key(TUI::KeyEvent.new(TUI::Key::Enter)).should eq(:commit)
      editor.value.should eq("hello")
      editor.cursor_offset.should eq({row: 0, col: 5})
    end

    it "commits the typed value intact when Enter is pressed" do
      editor = TUI::TextField.new(multiline: false)
      editor.start("")
      editor.handle_key(TUI::KeyEvent.new(TUI::Key::Char, 'h'))
      editor.handle_key(TUI::KeyEvent.new(TUI::Key::Char, 'i'))

      editor.handle_key(TUI::KeyEvent.new(TUI::Key::Enter)).should eq(:commit)
      editor.value.should eq("hi")
    end

    it "mentions Enter:commit in its status hint" do
      editor = TUI::TextField.new(multiline: false)
      editor.status_hint.should contain("Enter")
      editor.status_hint.should contain("commit")
    end
  end

  describe "#render" do
    it "draws every line of a multi-line value" do
      editor = TUI::TextField.new
      editor.start("one\ntwo\nthree")
      buffer = TUI::Buffer.new(20, 5)
      editor.render(buffer, 0, 0, 20, height: 3)

      (0...3).map { |col| buffer.cell(0, col).char }.join.should eq("one")
      (0...3).map { |col| buffer.cell(1, col).char }.join.should eq("two")
      (0...5).map { |col| buffer.cell(2, col).char }.join.should eq("three")
    end

    it "truncates lines past the given height without raising when the cursor is above the fold" do
      editor = TUI::TextField.new
      editor.start("one\ntwo\nthree")
      buffer = TUI::Buffer.new(20, 5)
      editor.render(buffer, 0, 0, 20, height: 2)

      (0...3).map { |col| buffer.cell(0, col).char }.join.should eq("one")
      (0...3).map { |col| buffer.cell(1, col).char }.join.should eq("two")
      buffer.cell(2, 0).char.should eq(" ")
    end

    it "scrolls the fixed-height window to keep the cursor's line visible instead of hiding it" do
      editor = TUI::TextField.new
      editor.start("one\ntwo\nthree")
      3.times { editor.handle_key(TUI::KeyEvent.new(TUI::Key::Down)) } # move to the last line ("three")

      buffer = TUI::Buffer.new(20, 5)
      editor.render(buffer, 0, 0, 20, height: 2)

      # Window scrolled down by one: shows lines 1-2 ("two", "three"),
      # not lines 0-1 — the cursor's line ("three") must be visible.
      (0...3).map { |col| buffer.cell(0, col).char }.join.should eq("two")
      (0...5).map { |col| buffer.cell(1, col).char }.join.should eq("three")
    end

    it "keeps growing text visible by scrolling as new lines push the cursor past the fixed height" do
      editor = TUI::TextField.new
      editor.start("")
      4.times do |i|
        editor.handle_key(TUI::KeyEvent.new(TUI::Key::Char, ('a'.ord + i).chr))
        editor.handle_key(TUI::KeyEvent.new(TUI::Key::Enter)) unless i == 3
      end
      # @text_lines is now ["a", "b", "c", "d"], cursor on line 3 ("d")

      buffer = TUI::Buffer.new(20, 5)
      editor.render(buffer, 0, 0, 20, height: 2)

      buffer.cell(0, 0).char.should eq("c")
      buffer.cell(1, 0).char.should eq("d")
    end

    it "does not reverse-video the cursor cell when focused: false" do
      editor = TUI::TextField.new
      editor.start("hi")
      buffer = TUI::Buffer.new(20, 5)
      editor.render(buffer, 0, 0, 20, focused: false)

      (0...2).each { |col| buffer.cell(0, col).style.should eq("") }
    end

    it "reverse-videos the cursor cell when focused: true (default)" do
      editor = TUI::TextField.new
      editor.start("hi")
      buffer = TUI::Buffer.new(20, 5)
      editor.render(buffer, 0, 0, 20)

      buffer.cell(0, 2).style.should contain("7")
    end
  end
end
