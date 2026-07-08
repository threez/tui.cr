require "../spec_helper"

private def scroll(visible = 15)
  TUI::ScrollControl.new(TUI::Scroller.new, visible)
end

describe TUI::MarkdownEdit do
  describe "inherits TextEdit editing behavior" do
    it "is a TextEdit and supports plain editing" do
      editor = TUI::MarkdownEdit.new("ab")
      editor.should be_a(TUI::TextEdit)
      editor.handle_key(TUI::KeyEvent.new(TUI::Key::Char, 'X'), scroll)
      editor.value.should eq("Xab")
    end
  end

  describe "highlighting preserves the raw source" do
    it "keeps Markdown delimiters in the value and rendered text (never strips them)" do
      editor = TUI::MarkdownEdit.new("**bold** and *italic* and `code`")
      buffer = TUI::Buffer.new(40, 3)
      editor.render_content(buffer, scroll)

      rendered = (0...32).map { |c| buffer.cell(0, c).char }.join
      rendered.should eq("**bold** and *italic* and `code`")
      editor.value.should eq("**bold** and *italic* and `code`")
    end

    it "keeps heading/list/blockquote prefixes intact" do
      editor = TUI::MarkdownEdit.new("# Heading\n- item\n> quote")
      buffer = TUI::Buffer.new(40, 3)
      editor.render_content(buffer, scroll)

      (0...9).map { |c| buffer.cell(0, c).char }.join.should eq("# Heading")
      (0...6).map { |c| buffer.cell(1, c).char }.join.should eq("- item")
      (0...7).map { |c| buffer.cell(2, c).char }.join.should eq("> quote")
    end

    it "cursor/edit positions stay aligned with the raw (unstripped) line after highlighting" do
      editor = TUI::MarkdownEdit.new("**bold** text")
      buffer = TUI::Buffer.new(40, 3)
      editor.render_content(buffer, scroll)

      editor.handle_key(TUI::KeyEvent.new(TUI::Key::End), scroll)
      editor.handle_key(TUI::KeyEvent.new(TUI::Key::Char, '!'), scroll)
      editor.value.should eq("**bold** text!")
    end
  end

  describe "styling" do
    it "styles a heading line with the configured heading style" do
      editor = TUI::MarkdownEdit.new("# Heading")
      buffer = TUI::Buffer.new(40, 3)
      editor.render_content(buffer, scroll)

      buffer.cell(0, 0).style.should_not eq("")
      buffer.cell(0, 0).style.should eq(buffer.cell(0, 1).style)
    end

    it "styles bold content differently from its delimiters" do
      editor = TUI::MarkdownEdit.new("**bold**")
      buffer = TUI::Buffer.new(40, 3)
      editor.render_content(buffer, scroll)

      buffer.cell(0, 0).style.should contain("2") # ** delimiter, dim
      buffer.cell(0, 2).style.should contain("1") # bold content
      buffer.cell(0, 6).style.should contain("2") # closing ** delimiter, dim
    end

    it "styles italic content differently from its delimiters" do
      editor = TUI::MarkdownEdit.new("*italic*")
      buffer = TUI::Buffer.new(40, 3)
      editor.render_content(buffer, scroll)

      buffer.cell(0, 0).style.should contain("2") # * delimiter, dim
      buffer.cell(0, 1).style.should contain("3") # italic content
    end

    it "styles inline code content differently from its backticks" do
      editor = TUI::MarkdownEdit.new("`code`")
      buffer = TUI::Buffer.new(40, 3)
      editor.render_content(buffer, scroll)

      buffer.cell(0, 0).style.should contain("2")     # ` delimiter, dim
      buffer.cell(0, 1).style.should_not contain("2") # code content, own color
    end

    it "styles strikethrough content differently from its ~~ delimiters, keeping them in the source" do
      editor = TUI::MarkdownEdit.new("~~struck~~")
      buffer = TUI::Buffer.new(40, 3)
      editor.render_content(buffer, scroll)

      rendered = (0...10).map { |c| buffer.cell(0, c).char }.join
      rendered.should eq("~~struck~~")
      buffer.cell(0, 0).style.should contain("2") # ~~ delimiter, dim
      buffer.cell(0, 1).style.should contain("2") # ~~ delimiter, dim
      buffer.cell(0, 2).style.should contain("9") # struck content
      buffer.cell(0, 8).style.should contain("2") # closing ~~ delimiter, dim
    end

    it "does not treat a single tilde as strikethrough" do
      editor = TUI::MarkdownEdit.new("a~b tilde")
      buffer = TUI::Buffer.new(40, 3)
      editor.render_content(buffer, scroll)

      buffer.cell(0, 1).style.should eq("")
    end

    it "does not style plain text" do
      editor = TUI::MarkdownEdit.new("just plain text")
      buffer = TUI::Buffer.new(40, 3)
      editor.render_content(buffer, scroll)

      buffer.cell(0, 0).style.should eq("")
    end

    it "leaves an unterminated delimiter as plain text instead of consuming the rest of the line" do
      editor = TUI::MarkdownEdit.new("this *never closes")
      buffer = TUI::Buffer.new(40, 3)
      editor.render_content(buffer, scroll)

      rendered = (0...18).map { |c| buffer.cell(0, c).char }.join
      rendered.should eq("this *never closes")
      buffer.cell(0, 5).style.should eq("")
    end
  end

  describe "in a Window" do
    it "renders bordered with a scrollbar like any other TextEdit" do
      screen = TUI::Screen.new
      editor = TUI::MarkdownEdit.new("# Hello")
      window = TUI::Window.new(1, 1, 20, 10, editor)
      window.composite(screen)

      screen.cell(1, 19).char.should eq(TUI::Term::VL)
    end
  end
end
