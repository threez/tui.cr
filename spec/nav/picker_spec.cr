require "../spec_helper"

private class StubPickable
  include TUI::Pickable

  property last_key : TUI::KeyEvent? = nil

  def initialize(@selected : String? = "picked")
  end

  def selected_value : String?
    @selected
  end

  def handle_key(ev : TUI::KeyEvent) : Bool
    @last_key = ev
    true
  end
end

describe TUI::Picker do
  describe "#handle_key" do
    it "calls on_cancel and consumes Esc" do
      widget = StubPickable.new
      canceled = false
      on_pick = ->(_v : String) { }
      on_cancel = -> { canceled = true; nil }
      picker = TUI::Picker.new(widget, on_pick, on_cancel)

      picker.handle_key(TUI::KeyEvent.new(TUI::Key::Esc)).should be_true
      canceled.should be_true
    end

    it "calls on_pick with the wrapped widget's selected_value on Enter" do
      widget = StubPickable.new(selected: "chosen")
      picked = nil.as(String?)
      on_pick = ->(v : String) { picked = v; nil }
      on_cancel = -> { }
      picker = TUI::Picker.new(widget, on_pick, on_cancel)

      picker.handle_key(TUI::KeyEvent.new(TUI::Key::Enter)).should be_true
      picked.should eq("chosen")
    end

    it "does not call on_pick when the wrapped widget has no selection" do
      widget = StubPickable.new(selected: nil)
      picked = nil.as(String?)
      on_pick = ->(v : String) { picked = v; nil }
      on_cancel = -> { }
      picker = TUI::Picker.new(widget, on_pick, on_cancel)

      picker.handle_key(TUI::KeyEvent.new(TUI::Key::Enter)).should be_true
      picked.should be_nil
    end

    it "swallows a suppressed char without forwarding it to the wrapped widget" do
      widget = StubPickable.new
      on_pick = ->(_v : String) { }
      on_cancel = -> { }
      picker = TUI::Picker.new(widget, on_pick, on_cancel, suppress: ['d'])

      picker.handle_key(TUI::KeyEvent.new(TUI::Key::Char, 'd')).should be_true
      widget.last_key.should be_nil
    end

    it "forwards a non-suppressed char to the wrapped widget" do
      widget = StubPickable.new
      on_pick = ->(_v : String) { }
      on_cancel = -> { }
      picker = TUI::Picker.new(widget, on_pick, on_cancel, suppress: ['d'])

      ev = TUI::KeyEvent.new(TUI::Key::Char, 'x')
      picker.handle_key(ev).should be_true
      widget.last_key.should eq(ev)
    end

    it "forwards any other key to the wrapped widget" do
      widget = StubPickable.new
      on_pick = ->(_v : String) { }
      on_cancel = -> { }
      picker = TUI::Picker.new(widget, on_pick, on_cancel)

      ev = TUI::KeyEvent.new(TUI::Key::Up)
      picker.handle_key(ev)
      widget.last_key.should eq(ev)
    end
  end
end
