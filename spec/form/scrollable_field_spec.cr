require "../spec_helper"

describe TUI::ScrollableField do
  describe "#start" do
    it "reseeds the wrapped content from a wire value" do
      field = TUI::ScrollableField(TUI::TextEdit).new(->(s : String) { TUI::TextEdit.new(s) })
      field.start("hello\nworld")
      field.value.should eq("hello\nworld")
    end
  end

  describe "#handle_key" do
    it "mutates value as characters are typed" do
      field = TUI::ScrollableField(TUI::TextEdit).new(->(s : String) { TUI::TextEdit.new(s) })
      field.start("")
      field.handle_key(TUI::KeyEvent.new(TUI::Key::Char, 'h'))
      field.handle_key(TUI::KeyEvent.new(TUI::Key::Char, 'i'))
      field.value.should eq("hi")
    end

    it "commits on Esc without clearing the text" do
      field = TUI::ScrollableField(TUI::TextEdit).new(->(s : String) { TUI::TextEdit.new(s) })
      field.start("hello")

      field.handle_key(TUI::KeyEvent.new(TUI::Key::Esc)).should eq(:commit)
      field.value.should eq("hello")
    end

    it "inserts a newline on Enter instead of committing" do
      field = TUI::ScrollableField(TUI::TextEdit).new(->(s : String) { TUI::TextEdit.new(s) })
      field.start("hello")
      field.handle_key(TUI::KeyEvent.new(TUI::Key::End))

      field.handle_key(TUI::KeyEvent.new(TUI::Key::Enter)).should be_nil
      field.value.should eq("hello\n")
    end
  end

  describe "#render" do
    it "renders into a narrow/short region without raising" do
      field = TUI::ScrollableField(TUI::TextEdit).new(->(s : String) { TUI::TextEdit.new(s) })
      field.start("one\ntwo\nthree\nfour\nfive")
      buffer = TUI::Buffer.new(10, 2)
      field.render(buffer, 0, 0, 10, height: 2)

      (0...3).map { |col| buffer.cell(0, col).char }.join.should eq("one")
    end

    it "scrolls rather than clips once content exceeds height" do
      field = TUI::ScrollableField(TUI::TextEdit).new(->(s : String) { TUI::TextEdit.new(s) })
      field.start("one\ntwo\nthree")
      3.times { field.handle_key(TUI::KeyEvent.new(TUI::Key::Down)) }

      buffer = TUI::Buffer.new(10, 2)
      field.render(buffer, 0, 0, 10, height: 2)

      (0...3).map { |col| buffer.cell(0, col).char }.join.should eq("two")
      (0...5).map { |col| buffer.cell(1, col).char }.join.should eq("three")
    end

    it "draws a scrollbar in the last column when content overflows height" do
      field = TUI::ScrollableField(TUI::TextEdit).new(->(s : String) { TUI::TextEdit.new(s) })
      field.start("one\ntwo\nthree\nfour\nfive")

      buffer = TUI::Buffer.new(10, 2)
      field.render(buffer, 0, 0, 10, height: 2)

      chars = (0...2).map { |row| buffer.cell(row, 9).char }
      chars.any? { |c| c != " " }.should be_true
    end

    it "leaves the last column blank when content fits without scrolling" do
      field = TUI::ScrollableField(TUI::TextEdit).new(->(s : String) { TUI::TextEdit.new(s) })
      field.start("one")

      buffer = TUI::Buffer.new(10, 2)
      field.render(buffer, 0, 0, 10, height: 2)

      buffer.cell(0, 9).char.should eq(" ")
      buffer.cell(1, 9).char.should eq(" ")
    end
  end

  describe "#status_hint" do
    it "includes both the wrapped content's hint and the commit hint" do
      field = TUI::ScrollableField(TUI::TextEdit).new(->(s : String) { TUI::TextEdit.new(s) })
      field.status_hint.should contain("Esc:commit")
    end
  end
end
