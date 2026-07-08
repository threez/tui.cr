require "../spec_helper"

describe TUI::Markdown::Wrap do
  describe ".wrap" do
    it "breaks only at whitespace boundaries, never splitting a word" do
      runs = [TUI::Markdown::InlineRun.new("one two three four five")]
      lines = TUI::Markdown::Wrap.wrap(runs, 11)

      lines.each { |l| l.map(&.text).join.size.should be <= 11 }
      lines.map { |l| l.map(&.text).join }.join.gsub(" ", "").should eq("onetwothreefourfive")
    end

    it "hard-breaks a single word longer than the width into width-sized chunks" do
      runs = [TUI::Markdown::InlineRun.new("supercalifragilistic")]
      lines = TUI::Markdown::Wrap.wrap(runs, 10)

      lines.map { |l| l.map(&.text).join }.should eq(["supercalif", "ragilistic"])
    end

    it "preserves a bold run's style across a wrap boundary without bleeding onto adjacent plain runs" do
      bold = TUI::Style.new(bold: true)
      plain = TUI::Style.new
      runs = [
        TUI::Markdown::InlineRun.new("plain word ", plain),
        TUI::Markdown::InlineRun.new("boldword", bold),
        TUI::Markdown::InlineRun.new(" more plain text", plain),
      ]

      lines = TUI::Markdown::Wrap.wrap(runs, 15)

      all_runs = lines.flatten
      bold_runs = all_runs.select { |r| r.text.includes?("boldword") }
      bold_runs.size.should eq(1)
      bold_runs[0].style.bold.should be_true

      plain_runs = all_runs.reject { |r| r.text.includes?("boldword") }
      plain_runs.all? { |r| !r.style.bold }.should be_true
    end

    it "drops leading whitespace at the start of a wrapped continuation line" do
      runs = [TUI::Markdown::InlineRun.new("one two three four five")]
      lines = TUI::Markdown::Wrap.wrap(runs, 11)

      lines[1..].each { |l| l.first.text.should_not start_with(" ") }
    end

    it "returns a single line unchanged when the input already fits within width" do
      runs = [TUI::Markdown::InlineRun.new("short")]
      lines = TUI::Markdown::Wrap.wrap(runs, 20)

      lines.size.should eq(1)
      lines[0].map(&.text).join.should eq("short")
    end

    it "merges adjacent same-style runs on the same output line into one run" do
      style = TUI::Style.new(bold: true)
      runs = [TUI::Markdown::InlineRun.new("foo ", style), TUI::Markdown::InlineRun.new("bar", style)]
      lines = TUI::Markdown::Wrap.wrap(runs, 20)

      lines.size.should eq(1)
      lines[0].size.should eq(1)
      lines[0][0].text.should eq("foo bar")
    end
  end
end
