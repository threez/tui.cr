require "../spec_helper"

private class Widget
  property name : String
  property active : String
  property color : String

  def initialize(@name, @active, @color)
  end
end

private COLOR_OPTIONS = [
  TUI::FormEnumOption.new("Red", "red"),
  TUI::FormEnumOption.new("Green", "green"),
  TUI::FormEnumOption.new("Blue", "blue"),
]

private def sample_fields : Array(TUI::Form::FieldSpec(Widget))
  [
    TUI::Form::FieldSpec(Widget).new("Name",
      get: ->(m : Widget) { m.name }, set: ->(m : Widget, v : String) { m.name = v; nil },
      build: -> { TUI::InputField.new.as(TUI::FormField) },
      validator: ->(v : String) { !v.empty? }, error_message: "Name required"),
    TUI::Form::FieldSpec(Widget).new("Active",
      get: ->(m : Widget) { m.active }, set: ->(m : Widget, v : String) { m.active = v; nil },
      build: -> { TUI::BoolField.new.as(TUI::FormField) }),
    TUI::Form::FieldSpec(Widget).new("Color",
      get: ->(m : Widget) { m.color }, set: ->(m : Widget, v : String) { m.color = v; nil },
      dropdown_options: COLOR_OPTIONS),
  ] of TUI::Form::FieldSpec(Widget)
end

private def sample_popup(screen : TUI::Screen) : {popup: TUI::Form::PopupHost, nav: TUI::NavStack(TUI::Widget)}
  root = TUI::Form::Host(Widget).new(1, 1, screen.cols, screen.rows - 1, sample_fields, Widget.new("bolt", "false", "red"),
    TUI::Form::PopupHost.new(screen: screen, push: ->(_w : TUI::Widget) { nil }, pop: -> { nil }))
  nav = TUI::NavStack(TUI::Widget).new(root.as(TUI::Widget))
  popup = TUI::Form::Host.popup_host(screen, nav)
  {popup: popup, nav: nav}
end

describe TUI::Form::Host do
  it "seeds each field's editor from the model via get, not a hardcoded default" do
    screen = TUI::Screen.new
    model = Widget.new("bolt", "true", "blue")
    wiring = sample_popup(screen)
    host = TUI::Form::Host(Widget).new(1, 1, screen.cols, screen.rows - 1, sample_fields, model, wiring[:popup])

    host.handle_key(TUI::KeyEvent.new(TUI::Key::Enter)) # start editing "Name"
    host.handle_key(TUI::KeyEvent.new(TUI::Key::Esc))   # InputField commits on Esc unchanged

    model.name.should eq("bolt")
  end

  it "commits a valid text edit back through set" do
    screen = TUI::Screen.new
    model = Widget.new("bolt", "false", "red")
    wiring = sample_popup(screen)
    host = TUI::Form::Host(Widget).new(1, 1, screen.cols, screen.rows - 1, sample_fields, model, wiring[:popup])

    host.handle_key(TUI::KeyEvent.new(TUI::Key::Enter))
    host.handle_key(TUI::KeyEvent.new(TUI::Key::Char, 'x'))
    host.handle_key(TUI::KeyEvent.new(TUI::Key::Esc))

    model.name.should eq("boltx")
  end

  it "rejects a commit that fails the field's validator, leaving the model untouched" do
    screen = TUI::Screen.new
    model = Widget.new("bolt", "false", "red")
    wiring = sample_popup(screen)
    host = TUI::Form::Host(Widget).new(1, 1, screen.cols, screen.rows - 1, sample_fields, model, wiring[:popup])

    host.handle_key(TUI::KeyEvent.new(TUI::Key::Enter))
    4.times { host.handle_key(TUI::KeyEvent.new(TUI::Key::Backspace)) }
    host.handle_key(TUI::KeyEvent.new(TUI::Key::Backspace)) # empties the field entirely
    host.handle_key(TUI::KeyEvent.new(TUI::Key::Esc))       # commit attempt, fails validator

    model.name.should eq("bolt")
    host.status_hint.should contain("commit") # still mid-edit, not back to nav hint
  end

  it "navigates focus with Tab and toggles a BoolField in place" do
    screen = TUI::Screen.new
    model = Widget.new("bolt", "false", "red")
    wiring = sample_popup(screen)
    host = TUI::Form::Host(Widget).new(1, 1, screen.cols, screen.rows - 1, sample_fields, model, wiring[:popup])

    host.handle_key(TUI::KeyEvent.new(TUI::Key::Tab)) # focus -> "Active"
    host.handle_key(TUI::KeyEvent.new(TUI::Key::Enter))
    host.handle_key(TUI::KeyEvent.new(TUI::Key::Char, ' '))
    host.handle_key(TUI::KeyEvent.new(TUI::Key::Enter)) # BoolField commits on Enter

    model.active.should eq("true")
  end

  it "also navigates focus with Down/Up, like before Grid existed" do
    screen = TUI::Screen.new
    model = Widget.new("bolt", "false", "red")
    wiring = sample_popup(screen)
    host = TUI::Form::Host(Widget).new(1, 1, screen.cols, screen.rows - 1, sample_fields, model, wiring[:popup])

    host.handle_key(TUI::KeyEvent.new(TUI::Key::Down)) # focus -> "Active"
    host.handle_key(TUI::KeyEvent.new(TUI::Key::Enter))
    host.handle_key(TUI::KeyEvent.new(TUI::Key::Char, ' '))
    host.handle_key(TUI::KeyEvent.new(TUI::Key::Enter)) # BoolField commits on Enter
    model.active.should eq("true")

    host.handle_key(TUI::KeyEvent.new(TUI::Key::Up)) # back to "Name"
    host.handle_key(TUI::KeyEvent.new(TUI::Key::Enter))
    host.handle_key(TUI::KeyEvent.new(TUI::Key::Char, 'x'))
    host.handle_key(TUI::KeyEvent.new(TUI::Key::Esc))
    model.name.should eq("boltx")
  end

  it "does not let Down/Up leak into an actively-editing ScrollableField, only move its cursor" do
    screen = TUI::Screen.new
    model = Widget.new("bolt", "false", "red")
    fields = [
      TUI::Form::FieldSpec(Widget).new("Name",
        get: ->(m : Widget) { m.name }, set: ->(m : Widget, v : String) { m.name = v; nil },
        build: -> { TUI::ScrollableField(TUI::TextEdit).new(->(s : String) { TUI::TextEdit.new(s) }).as(TUI::FormField) },
        rows: 3),
      TUI::Form::FieldSpec(Widget).new("Active",
        get: ->(m : Widget) { m.active }, set: ->(m : Widget, v : String) { m.active = v; nil },
        build: -> { TUI::BoolField.new.as(TUI::FormField) }),
    ] of TUI::Form::FieldSpec(Widget)
    popup = TUI::Form::PopupHost.new(screen: screen, push: ->(_w : TUI::Widget) { nil }, pop: -> { nil })
    host = TUI::Form::Host(Widget).new(1, 1, screen.cols, screen.rows - 1, fields, model, popup)

    host.handle_key(TUI::KeyEvent.new(TUI::Key::Enter)) # start editing multi-line "Name"
    host.handle_key(TUI::KeyEvent.new(TUI::Key::Char, 'x'))
    host.handle_key(TUI::KeyEvent.new(TUI::Key::Enter)) # newline, not commit
    host.handle_key(TUI::KeyEvent.new(TUI::Key::Char, 'y'))
    host.handle_key(TUI::KeyEvent.new(TUI::Key::Up))  # must move the field's own cursor, not Grid focus
    host.handle_key(TUI::KeyEvent.new(TUI::Key::Esc)) # commits back to "Name"

    model.name.should eq("x\nybolt")
    model.active.should eq("false") # never toggled — focus never reached "Active"
  end

  it "pushes a dropdown popup through the PopupHost for a dropdown_options field" do
    screen = TUI::Screen.new
    model = Widget.new("bolt", "false", "red")
    pushed = [] of TUI::Widget
    popup = TUI::Form::PopupHost.new(screen: screen,
      push: ->(w : TUI::Widget) { pushed << w; nil },
      pop: -> { nil })
    host = TUI::Form::Host(Widget).new(1, 1, screen.cols, screen.rows - 1, sample_fields, model, popup)

    host.handle_key(TUI::KeyEvent.new(TUI::Key::Tab)) # "Active"
    host.handle_key(TUI::KeyEvent.new(TUI::Key::Tab)) # "Color"
    host.handle_key(TUI::KeyEvent.new(TUI::Key::Enter))

    pushed.size.should eq(1)
    pushed.first.should be_a(TUI::Window)
  end

  it "renders without error and shows field labels" do
    screen = TUI::Screen.new
    model = Widget.new("bolt", "false", "red")
    wiring = sample_popup(screen)
    host = TUI::Form::Host(Widget).new(1, 1, screen.cols, screen.rows - 1, sample_fields, model, wiring[:popup])

    host.composite(screen)

    screen.cell(1, 2).char.should eq("N") # "Name" label, past the "▸" pointer at col 1
  end

  describe ".full_screen" do
    it "sizes and positions to fill the screen below the status bar row" do
      screen = TUI::Screen.new
      wiring = sample_popup(screen)
      host = TUI::Form::Host.full_screen(screen, sample_fields, Widget.new("bolt", "false", "red"), wiring[:popup])

      host.x.should eq(1)
      host.y.should eq(1)
      host.width.should eq(screen.cols)
      host.height.should eq(screen.rows - 1)
    end
  end
end
