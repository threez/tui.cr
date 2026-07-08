require "../spec_helper"

describe TUI::Markdown::Inline do
  describe ".parse" do
    it "splits bold and italic spans into InlineRuns with the correct styles, plain text elsewhere" do
      runs = TUI::Markdown::Inline.parse("plain **bold** and *italic* text")

      runs.map(&.text).join.should eq("plain bold and italic text")
      bold_run = runs.find { |r| r.text == "bold" }.not_nil!
      bold_run.style.bold.should be_true

      italic_run = runs.find { |r| r.text == "italic" }.not_nil!
      italic_run.style.italic.should be_true
    end

    it "handles bold+italic (triple delimiter) as one run with the combined style" do
      runs = TUI::Markdown::Inline.parse("***both***")
      runs.size.should eq(1)
      runs[0].text.should eq("both")
      runs[0].style.bold.should be_true
      runs[0].style.italic.should be_true
    end

    it "splits a strikethrough span into an InlineRun with strikethrough styling" do
      runs = TUI::Markdown::Inline.parse("plain ~~struck~~ text")

      runs.map(&.text).join.should eq("plain struck text")
      struck_run = runs.find { |r| r.text == "struck" }.not_nil!
      struck_run.style.strikethrough.should be_true
    end

    it "leaves an unterminated strikethrough delimiter as literal text instead of consuming the rest of the line" do
      runs = TUI::Markdown::Inline.parse("a stray ~~ tilde with no match")
      runs.map(&.text).join.should eq("a stray ~~ tilde with no match")
    end

    it "does not treat a single tilde as strikethrough syntax" do
      runs = TUI::Markdown::Inline.parse("a~b tilde")
      runs.map(&.text).join.should eq("a~b tilde")
      runs.any?(&.style.strikethrough).should be_false
    end

    it "styles inline code distinctly and preserves its literal text" do
      runs = TUI::Markdown::Inline.parse("use `puts x` here")
      code_run = runs.find { |r| r.text == "puts x" }.not_nil!
      code_run.style.should eq(TUI::Style.new(fg: TUI.color(:yellow)))
    end

    it "renders a link as one run with link_style, url preserved in the text" do
      runs = TUI::Markdown::Inline.parse("[text](http://example.com)")
      runs.size.should eq(1)
      runs[0].text.should eq("text (http://example.com)")
      runs[0].style.fg.should eq(TUI.color(:blue))
    end

    it "un-escapes a backslash-escaped delimiter to a literal character without triggering emphasis" do
      runs = TUI::Markdown::Inline.parse("a \\*not italic\\* here")
      runs.size.should eq(1)
      runs[0].text.should eq("a *not italic* here")
      runs[0].style.italic.should be_false
    end

    it "leaves an unterminated emphasis delimiter as literal text instead of hanging or consuming the rest of the line" do
      runs = TUI::Markdown::Inline.parse("a stray * asterisk with no match")
      runs.map(&.text).join.should eq("a stray * asterisk with no match")
    end

    it "accepts a custom Config overriding the default styles" do
      config = TUI::Markdown::Inline::Config.new(bold_style: TUI::Style.new(underline: true))
      runs = TUI::Markdown::Inline.parse("**bold**", config: config)
      runs[0].style.underline.should be_true
      runs[0].style.bold.should be_false
    end
  end
end
