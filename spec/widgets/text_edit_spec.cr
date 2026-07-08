require "../spec_helper"

private def scroll(visible = 15)
  TUI::ScrollControl.new(TUI::Scroller.new, visible)
end

describe TUI::TextEdit do
  describe "editing" do
    it "inserts typed characters at the cursor" do
      editor = TUI::TextEdit.new("ab")
      editor.handle_key(TUI::KeyEvent.new(TUI::Key::Char, 'X'), scroll)
      editor.value.should eq("Xab")
    end

    it "splits the line at the cursor on Enter" do
      editor = TUI::TextEdit.new("hello")
      3.times { editor.handle_key(TUI::KeyEvent.new(TUI::Key::Right), scroll) }
      editor.handle_key(TUI::KeyEvent.new(TUI::Key::Enter), scroll)
      editor.value.should eq("hel\nlo")
    end

    it "merges the previous line on Backspace at column 0" do
      editor = TUI::TextEdit.new("one\ntwo")
      editor.handle_key(TUI::KeyEvent.new(TUI::Key::Down), scroll)
      editor.handle_key(TUI::KeyEvent.new(TUI::Key::Home), scroll)
      editor.handle_key(TUI::KeyEvent.new(TUI::Key::Backspace), scroll)
      editor.value.should eq("onetwo")
    end

    it "merges the next line on Delete at end of line" do
      editor = TUI::TextEdit.new("one\ntwo")
      editor.handle_key(TUI::KeyEvent.new(TUI::Key::End), scroll)
      editor.handle_key(TUI::KeyEvent.new(TUI::Key::Delete), scroll)
      editor.value.should eq("onetwo")
    end
  end

  describe "cursor movement" do
    it "moves left and right" do
      editor = TUI::TextEdit.new("hi")
      editor.handle_key(TUI::KeyEvent.new(TUI::Key::Right), scroll)
      editor.handle_key(TUI::KeyEvent.new(TUI::Key::Char, 'X'), scroll)
      editor.value.should eq("hXi")
    end

    it "wraps Left to the end of the previous line" do
      editor = TUI::TextEdit.new("ab\ncd")
      editor.handle_key(TUI::KeyEvent.new(TUI::Key::Down), scroll)
      editor.handle_key(TUI::KeyEvent.new(TUI::Key::Home), scroll)
      editor.handle_key(TUI::KeyEvent.new(TUI::Key::Left), scroll)
      editor.handle_key(TUI::KeyEvent.new(TUI::Key::Char, 'X'), scroll)
      editor.value.should eq("abX\ncd")
    end

    it "moves the cursor down and up across wrapped segments of one long line, preserving visual column" do
      editor = TUI::TextEdit.new("this is a very long line that should wrap across multiple rows")
      buf = TUI::Buffer.new(20, 8)
      s = scroll(8)
      editor.render_content(buf, s) # establish layout at width 20

      5.times { editor.handle_key(TUI::KeyEvent.new(TUI::Key::Right), s) } # visual col 5, segment 0
      editor.handle_key(TUI::KeyEvent.new(TUI::Key::Down), s)              # segment 1, visual col 5
      editor.handle_key(TUI::KeyEvent.new(TUI::Key::Down), s)              # segment 2, visual col 5
      editor.handle_key(TUI::KeyEvent.new(TUI::Key::Char, '|'), s)

      editor.value.should eq("this is a very long line that should wrap a|cross multiple rows")
    end
  end

  describe "#content_size" do
    it "equals the logical line count when nothing wraps" do
      editor = TUI::TextEdit.new("one\ntwo\nthree")
      buf = TUI::Buffer.new(20, 5)
      editor.render_content(buf, scroll)
      editor.content_size.should eq(3)
    end

    it "counts extra visual rows for a wrapped long line" do
      editor = TUI::TextEdit.new("this is a very long line that should wrap across multiple rows")
      buf = TUI::Buffer.new(20, 8)
      editor.render_content(buf, scroll(8))
      editor.content_size.should be > 1
    end
  end

  describe "#render_content" do
    it "draws every line of unwrapped multi-line text" do
      editor = TUI::TextEdit.new("one\ntwo\nthree")
      buffer = TUI::Buffer.new(20, 5)
      editor.render_content(buffer, scroll)

      (0...3).map { |c| buffer.cell(0, c).char }.join.should eq("one")
      (0...3).map { |c| buffer.cell(1, c).char }.join.should eq("two")
      (0...5).map { |c| buffer.cell(2, c).char }.join.should eq("three")
    end

    it "wraps a long line across multiple rows with a trailing marker on every non-final segment" do
      editor = TUI::TextEdit.new("this is a very long line that should wrap across multiple rows")
      buffer = TUI::Buffer.new(20, 8)
      editor.render_content(buffer, scroll(8))

      buffer.cell(0, 19).char.should eq(TUI::TextEdit::WRAP_MARKER)
      buffer.cell(1, 19).char.should eq(TUI::TextEdit::WRAP_MARKER)
      buffer.cell(2, 19).char.should eq(TUI::TextEdit::WRAP_MARKER)
      (0...5).map { |c| buffer.cell(3, c).char }.join.should eq(" rows")
    end

    it "does not append a marker on a line's final (or only) segment" do
      editor = TUI::TextEdit.new("short")
      buffer = TUI::Buffer.new(20, 5)
      editor.render_content(buffer, scroll)

      buffer.cell(0, 19).char.should eq(" ")
    end

    it "does not reverse-video the cursor cell when unfocused" do
      editor = TUI::TextEdit.new("hi")
      buffer = TUI::Buffer.new(20, 5)
      editor.render_content(buffer, scroll)

      (0...2).each { |c| buffer.cell(0, c).style.should eq("") }
    end

    it "reverse-videos the cursor cell when focused" do
      editor = TUI::TextEdit.new("hi")
      editor.focus_if(true)
      buffer = TUI::Buffer.new(20, 5)
      editor.render_content(buffer, scroll)

      buffer.cell(0, 0).style.should contain("7")
    end
  end

  describe "#handle_click" do
    it "places the cursor at the clicked row/column" do
      editor = TUI::TextEdit.new("hello\nworld")
      buffer = TUI::Buffer.new(20, 5)
      editor.render_content(buffer, scroll)

      editor.handle_click(1, 2, scroll).should be_true
      editor.handle_key(TUI::KeyEvent.new(TUI::Key::Char, '!'), scroll)
      editor.value.should eq("hello\nwo!rld")
    end
  end

  describe "scroll keys" do
    it "handles PageUp/PageDown/wheel via ScrollControl" do
      editor = TUI::TextEdit.new((1..20).map { |i| "line#{i}" }.join('\n'))
      buffer = TUI::Buffer.new(20, 5)
      s = scroll(5)
      editor.render_content(buffer, s)

      editor.handle_key(TUI::KeyEvent.new(TUI::Key::PageDown), s).should be_true
      s.offset.should be > 0

      editor.handle_key(TUI::KeyEvent.new(TUI::Key::PageUp), s).should be_true
      s.offset.should eq(0)

      editor.handle_key(TUI::KeyEvent.new(TUI::Key::MouseWheelDown), s).should be_true
      editor.handle_key(TUI::KeyEvent.new(TUI::Key::MouseWheelUp), s).should be_true
    end
  end

  describe "in a Window" do
    it "shows no scrollbar when content fits" do
      screen = TUI::Screen.new
      editor = TUI::TextEdit.new("hi")
      window = TUI::Window.new(1, 1, 20, 10, editor)
      window.composite(screen)

      screen.cell(1, 19).char.should eq(TUI::Term::VL)
    end

    it "shows a scrollbar thumb once wrapped/long content overflows the viewport" do
      screen = TUI::Screen.new
      editor = TUI::TextEdit.new((1..30).map { |i| "line#{i}" }.join('\n'))
      window = TUI::Window.new(1, 1, 20, 10, editor)
      window.composite(screen)

      (1...9).map { |r| screen.cell(r, 19).char }.should contain("▐")
    end
  end
end
