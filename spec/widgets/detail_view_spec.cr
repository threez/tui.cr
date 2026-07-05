require "../spec_helper"

private class StubDetailSource < TUI::DetailDataSource
  def title(id : String) : String
    "Detail: #{id}"
  end

  def lines(id : String, expansions : Set(Symbol)) : Array(TUI::DetailLine)
    [TUI::DetailLine.new("Name", id)]
  end

  def toggles : Array(Symbol)
    [:rdeps, :shlib_users]
  end

  def toggle_label(sym : Symbol) : String
    case sym
    when :rdeps       then "dependents"
    when :shlib_users then "lib users"
    else                   sym.to_s
    end
  end
end

private def scroll(visible = 15)
  TUI::ScrollControl.new(TUI::Scroller.new, visible)
end

describe TUI::DetailView do
  describe "toggle key assignment" do
    it "assigns 'a' to the first toggle and 'b' to the second, in source.toggles order" do
      view = TUI::DetailView.new(StubDetailSource.new)
      view.load("pkg")

      view.handle_key(TUI::KeyEvent.new(TUI::Key::Char, 'a'), scroll).should be_true
      view.handle_key(TUI::KeyEvent.new(TUI::Key::Char, 'b'), scroll).should be_true
    end

    it "does not respond to 'r' or 'l' — the old hardcoded hint text was wrong" do
      view = TUI::DetailView.new(StubDetailSource.new)
      view.load("pkg")

      view.handle_key(TUI::KeyEvent.new(TUI::Key::Char, 'r'), scroll).should be_false
      view.handle_key(TUI::KeyEvent.new(TUI::Key::Char, 'l'), scroll).should be_false
    end
  end

  describe "#status_hint" do
    it "pairs each real toggle letter with its actual label, matching dispatch exactly" do
      view = TUI::DetailView.new(StubDetailSource.new)
      view.load("pkg")

      view.status_hint.should eq(" ↑↓/PgUp/PgDn:scroll a:dependents  b:lib users  Esc:back")
    end
  end

  describe "scroll keys" do
    it "still handles Up/Down/PageUp/PageDown/wheel unaffected by the toggle menu" do
      view = TUI::DetailView.new(StubDetailSource.new)
      view.load("pkg")

      view.handle_key(TUI::KeyEvent.new(TUI::Key::Up), scroll).should be_true
      view.handle_key(TUI::KeyEvent.new(TUI::Key::Down), scroll).should be_true
      view.handle_key(TUI::KeyEvent.new(TUI::Key::PageUp), scroll).should be_true
      view.handle_key(TUI::KeyEvent.new(TUI::Key::PageDown), scroll).should be_true
      view.handle_key(TUI::KeyEvent.new(TUI::Key::MouseWheelUp), scroll).should be_true
      view.handle_key(TUI::KeyEvent.new(TUI::Key::MouseWheelDown), scroll).should be_true
    end
  end
end
