require "../spec_helper"

private class StubWidget < TUI::Widget
  def render : Nil
  end

  def handle_key(ev : TUI::KeyEvent) : Bool
    false
  end

  def status_hint : String
    ""
  end
end

describe TUI::Form::PopupHost do
  it "carries the screen and forwards push/pop calls" do
    root = StubWidget.new(1, 1, 5, 5)
    nav = TUI::NavStack(TUI::Widget).new(root.as(TUI::Widget))
    screen = TUI::Screen.new
    popup = TUI::Form::Host.popup_host(screen, nav)

    popup.screen.should be(screen)

    pushed = StubWidget.new(1, 1, 5, 5)
    popup.push.call(pushed.as(TUI::Widget))
    nav.current.should be(pushed)

    popup.pop.call
    nav.current.should be(root)
  end
end
