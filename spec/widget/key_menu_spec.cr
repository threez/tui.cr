require "../spec_helper"

describe TUI::KeyMenu do
  describe "#dispatch" do
    it "matches a Char trigger and invokes its action" do
      menu = TUI::KeyMenu.new
      called = false
      menu.bind('q', "q:quit") { called = true }

      menu.dispatch(TUI::KeyEvent.new(TUI::Key::Char, 'q')).should be_true
      called.should be_true
    end

    it "matches a Key trigger" do
      menu = TUI::KeyMenu.new
      called = false
      menu.bind(TUI::Key::Enter, "Enter:open") { called = true }

      menu.dispatch(TUI::KeyEvent.new(TUI::Key::Enter)).should be_true
      called.should be_true
    end

    it "passes the KeyEvent to a block that accepts one" do
      menu = TUI::KeyMenu.new
      received = nil.as(TUI::KeyEvent?)
      menu.bind('q', "q:quit") { |event| received = event; true }

      ev = TUI::KeyEvent.new(TUI::Key::Char, 'q')
      menu.dispatch(ev)

      received.should eq(ev)
    end

    it "returns false when nothing matches" do
      menu = TUI::KeyMenu.new
      menu.bind('q', "q:quit") { }

      menu.dispatch(TUI::KeyEvent.new(TUI::Key::Char, 'z')).should be_false
    end

    it "tries bindings in registration order, first match wins" do
      menu = TUI::KeyMenu.new
      order = [] of String
      menu.bind('a', "a:first") { order << "first" }
      menu.bind('a', "a:second") { order << "second" }

      menu.dispatch(TUI::KeyEvent.new(TUI::Key::Char, 'a'))

      order.should eq(["first"])
    end

    it "skips a binding whose when: predicate is false" do
      menu = TUI::KeyMenu.new
      gate = false
      menu.bind('a', "a:stage", when: -> { gate }) { }

      menu.dispatch(TUI::KeyEvent.new(TUI::Key::Char, 'a')).should be_false
      gate = true
      menu.dispatch(TUI::KeyEvent.new(TUI::Key::Char, 'a')).should be_true
    end
  end

  describe "#hint" do
    it "joins active bindings' labels in registration order" do
      menu = TUI::KeyMenu.new
      menu.bind('a', "a:stage") { }
      menu.bind('b', "b:unstage") { }

      menu.hint.should eq(" a:stage  b:unstage")
    end

    it "excludes bindings whose when: predicate is currently false" do
      menu = TUI::KeyMenu.new
      menu.bind('a', "a:stage", when: -> { false }) { }
      menu.bind('b', "b:unstage") { }

      menu.hint.should eq(" b:unstage")
    end

    it "is just a leading space when there are no active bindings" do
      menu = TUI::KeyMenu.new
      menu.hint.should eq(" ")
    end
  end
end
