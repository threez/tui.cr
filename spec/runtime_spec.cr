require "./spec_helper"

private class TestWidget < TUI::Widget
  def render : Nil
  end

  def handle_key(ev : TUI::KeyEvent) : Bool
    false
  end

  def status_hint : String
    ""
  end
end

describe TUI::Runtime do
  describe "#push" do
    it "resizes the pushed widget to the screen's current dimensions" do
      screen = TUI::Screen.new
      root = TestWidget.new(1, 1, 1, 1)
      nav = TUI::NavStack(TUI::Widget).new(root.as(TUI::Widget))
      runtime = TUI::Runtime.new(screen, nav, ->(_ev : TUI::KeyEvent) { nil })

      pushed = TestWidget.new(1, 1, 1, 1)
      runtime.push(pushed.as(TUI::Widget))

      pushed.width.should eq(screen.cols)
      pushed.height.should eq(screen.rows - 1)
      nav.current.should eq(pushed)
    end
  end

  describe "#pop" do
    it "resyncs the revealed widget's size" do
      screen = TUI::Screen.new
      root = TestWidget.new(1, 1, 1, 1)
      nav = TUI::NavStack(TUI::Widget).new(root.as(TUI::Widget))
      runtime = TUI::Runtime.new(screen, nav, ->(_ev : TUI::KeyEvent) { nil })

      pushed = TestWidget.new(1, 1, 1, 1)
      runtime.push(pushed.as(TUI::Widget))

      # simulate the root having gone stale while backgrounded
      root.width = 1
      root.height = 1

      runtime.pop

      nav.current.should eq(root)
      root.width.should eq(screen.cols)
      root.height.should eq(screen.rows - 1)
    end
  end

  describe "#replace_base" do
    it "resizes the new base widget to the screen's current dimensions" do
      screen = TUI::Screen.new
      root = TestWidget.new(1, 1, 1, 1)
      nav = TUI::NavStack(TUI::Widget).new(root.as(TUI::Widget))
      runtime = TUI::Runtime.new(screen, nav, ->(_ev : TUI::KeyEvent) { nil })

      replacement = TestWidget.new(1, 1, 1, 1)
      runtime.replace_base(replacement.as(TUI::Widget))

      replacement.width.should eq(screen.cols)
      replacement.height.should eq(screen.rows - 1)
      nav.current.should eq(replacement)
    end

    it "leaves anything pushed on top of the base untouched" do
      screen = TUI::Screen.new
      root = TestWidget.new(1, 1, 1, 1)
      nav = TUI::NavStack(TUI::Widget).new(root.as(TUI::Widget))
      runtime = TUI::Runtime.new(screen, nav, ->(_ev : TUI::KeyEvent) { nil })

      pushed = TestWidget.new(1, 1, 1, 1)
      runtime.push(pushed.as(TUI::Widget))

      replacement = TestWidget.new(1, 1, 1, 1)
      runtime.replace_base(replacement.as(TUI::Widget))

      nav.current.should eq(pushed)
    end
  end

  describe "#handle_esc" do
    it "does not pop when consumed is true" do
      screen = TUI::Screen.new
      root = TestWidget.new(1, 1, 1, 1)
      nav = TUI::NavStack(TUI::Widget).new(root.as(TUI::Widget))
      runtime = TUI::Runtime.new(screen, nav, ->(_ev : TUI::KeyEvent) { nil })

      pushed = TestWidget.new(1, 1, 1, 1)
      runtime.push(pushed.as(TUI::Widget))

      on_pop_called = false
      runtime.handle_esc(true) { on_pop_called = true }

      nav.current.should eq(pushed)
      on_pop_called.should be_false
    end

    it "pops, resizes the revealed widget, and calls on_pop when consumed is false" do
      screen = TUI::Screen.new
      root = TestWidget.new(1, 1, 1, 1)
      nav = TUI::NavStack(TUI::Widget).new(root.as(TUI::Widget))
      runtime = TUI::Runtime.new(screen, nav, ->(_ev : TUI::KeyEvent) { nil })

      pushed = TestWidget.new(1, 1, 1, 1)
      runtime.push(pushed.as(TUI::Widget))

      # simulate the root having gone stale while backgrounded
      root.width = 1
      root.height = 1

      on_pop_called = false
      runtime.handle_esc(false) { on_pop_called = true }

      nav.current.should eq(root)
      root.width.should eq(screen.cols)
      root.height.should eq(screen.rows - 1)
      on_pop_called.should be_true
    end
  end

  describe "#read_dispatch_loop" do
    it "dispatches non-quit keys to on_key and stops on Ctrl-C" do
      screen = TUI::Screen.new
      root = TestWidget.new(1, 1, screen.cols, screen.rows - 1)
      nav = TUI::NavStack(TUI::Widget).new(root.as(TUI::Widget))

      dispatched = [] of TUI::Key
      io = IO::Memory.new("a")
      runtime = TUI::Runtime.new(screen, nav, ->(ev : TUI::KeyEvent) {
        dispatched << ev.key
        nil
      }, io)

      runtime.read_dispatch_loop

      dispatched.should eq([TUI::Key::Char])
    end

    it "stops on Ctrl-D without dispatching it" do
      screen = TUI::Screen.new
      root = TestWidget.new(1, 1, screen.cols, screen.rows - 1)
      nav = TUI::NavStack(TUI::Widget).new(root.as(TUI::Widget))

      dispatched = [] of TUI::Key
      io = IO::Memory.new("")
      runtime = TUI::Runtime.new(screen, nav, ->(ev : TUI::KeyEvent) {
        dispatched << ev.key
        nil
      }, io)

      runtime.read_dispatch_loop

      dispatched.should be_empty
    end
  end
end
