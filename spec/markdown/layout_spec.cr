require "../spec_helper"

describe TUI::Markdown::Layout do
  describe ".layout" do
    it "indents a heading by (level-1)*heading_indent_step columns and prefixes it with the computed number" do
      blocks = TUI::Markdown::Parser.parse("# A\n\n## B")
      rows = TUI::Markdown::Layout.layout(blocks, 40)

      texts = rows.map { |r| r.map(&.text).join }
      texts.should contain("1  A")
      texts.should contain("  1.1  B")
    end

    it "produces one row per list item plus one continuation row per wrapped overflow, aligned under the text not the marker" do
      blocks = TUI::Markdown::Parser.parse("- this item is long enough that it must wrap onto more than one physical row of output")
      rows = TUI::Markdown::Layout.layout(blocks, 20)

      rows.size.should be > 1
      rows[1..].each { |r| r.map(&.text).join.should start_with("  ") }
      rows[0].map(&.text).join.should start_with("• ")
    end

    it "computes table column widths from content, shrinking proportionally with a floor when narrower than natural width" do
      blocks = TUI::Markdown::Parser.parse(<<-MD)
        | Name | Description |
        |------|-------------|
        | A    | short       |
        | BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB | x |
        MD

      rows = TUI::Markdown::Layout.layout(blocks, 20)
      rows.each { |r| r.map(&.text).join.size.should be <= 20 }
    end

    it "renders a GFM table with box-drawing borders at the expected positions" do
      blocks = TUI::Markdown::Parser.parse(<<-MD)
        | A | B |
        |---|---|
        | 1 | 2 |
        MD

      rows = TUI::Markdown::Layout.layout(blocks, 40).map { |r| r.map(&.text).join }
      rows[0].should start_with(TUI::Term::TL)
      rows[0].should end_with(TUI::Term::TR)
      rows[0].should contain(TUI::Term::TJ)
      rows[2].should start_with(TUI::Term::LJ)
      rows[2].should contain(TUI::Term::CJ)
      rows.last.should start_with(TUI::Term::BL)
      rows.last.should end_with(TUI::Term::BR)
    end

    it "never wraps a fenced code block's lines regardless of width" do
      long_line = "x" * 60
      blocks = [TUI::Markdown::CodeBlock.new([long_line]).as(TUI::Markdown::Block)]
      rows = TUI::Markdown::Layout.layout(blocks, 20)

      rows.size.should eq(1)
      rows[0].map(&.text).join.should eq(long_line)
    end
  end
end
