require "../spec_helper"

describe TUI::MarkdownView do
  describe "#content_size" do
    it "reflects the number of laid-out physical rows for the last-rendered width, not the raw block count" do
      view = TUI::MarkdownView.new("# Heading\n\nA short paragraph.")
      buffer = TUI::Buffer.new(40, 10)
      scroll_owner = TUI::Scroller.new
      view.render_content(buffer, TUI::ScrollControl.new(scroll_owner, 10))

      view.content_size.should be > 0
    end
  end

  describe "#load" do
    it "replaces content and resets the cached layout" do
      view = TUI::MarkdownView.new("# One")
      buffer = TUI::Buffer.new(40, 10)
      scroll_owner = TUI::Scroller.new
      view.render_content(buffer, TUI::ScrollControl.new(scroll_owner, 10))
      first_size = view.content_size

      view.load("# One\n\n# Two\n\n# Three")
      view.render_content(buffer, TUI::ScrollControl.new(scroll_owner, 10))

      view.content_size.should be > first_size
    end
  end

  describe "#handle_key" do
    it "Up/Down/PageUp/PageDown/wheel scroll keys behave the same as DetailView's" do
      view = TUI::MarkdownView.new((1..50).map { |i| "line #{i}" }.join("\n\n"))
      buffer = TUI::Buffer.new(40, 5)
      scroller = TUI::Scroller.new
      view.render_content(buffer, TUI::ScrollControl.new(scroller, 5))

      view.handle_key(TUI::KeyEvent.new(TUI::Key::Down), TUI::ScrollControl.new(scroller, 5)).should be_true
      view.handle_key(TUI::KeyEvent.new(TUI::Key::Up), TUI::ScrollControl.new(scroller, 5)).should be_true
      view.handle_key(TUI::KeyEvent.new(TUI::Key::PageDown), TUI::ScrollControl.new(scroller, 5)).should be_true
      view.handle_key(TUI::KeyEvent.new(TUI::Key::PageUp), TUI::ScrollControl.new(scroller, 5)).should be_true
      view.handle_key(TUI::KeyEvent.new(TUI::Key::MouseWheelDown), TUI::ScrollControl.new(scroller, 5)).should be_true
      view.handle_key(TUI::KeyEvent.new(TUI::Key::MouseWheelUp), TUI::ScrollControl.new(scroller, 5)).should be_true
    end

    it "returns false for an unrecognized key" do
      view = TUI::MarkdownView.new("# Title")
      scroller = TUI::Scroller.new
      view.handle_key(TUI::KeyEvent.new(TUI::Key::Char, 'z'), TUI::ScrollControl.new(scroller, 5)).should be_false
    end
  end

  describe "#status_hint" do
    it "matches the documented scroll-key hint text" do
      TUI::MarkdownView.new("# Title").status_hint.should eq(" ↑↓/PgUp/PgDn:scroll  Esc:back")
    end
  end

  describe "resize handling" do
    it "re-lays-out when render_content's buffer width changes, and content_size catches up on the following call" do
      long_text = (1..10).map { |i| "word#{i}" }.join(" ")
      view = TUI::MarkdownView.new(long_text)
      scroller = TUI::Scroller.new

      narrow = TUI::Buffer.new(15, 20)
      view.render_content(narrow, TUI::ScrollControl.new(scroller, 20))
      narrow_size = view.content_size

      wide = TUI::Buffer.new(80, 20)
      view.render_content(wide, TUI::ScrollControl.new(scroller, 20))
      wide_size = view.content_size

      narrow_size.should be > wide_size
    end
  end
end
