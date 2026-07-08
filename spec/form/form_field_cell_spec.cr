require "../spec_helper"

private class Widget
  property name : String

  def initialize(@name)
  end
end

private def sample_field(validator : (String -> Bool)? = nil) : TUI::Form::FieldSpec(Widget)
  TUI::Form::FieldSpec(Widget).new("Name",
    get: ->(m : Widget) { m.name }, set: ->(m : Widget, v : String) { m.name = v; nil },
    build: -> { TUI::InputField.new.as(TUI::FormField) },
    validator: validator, error_message: "Name required")
end

private def sample_popup(screen : TUI::Screen) : TUI::Form::PopupHost
  TUI::Form::PopupHost.new(screen: screen, push: ->(_w : TUI::Widget) { nil }, pop: -> { nil })
end

describe TUI::Form::FormFieldCell do
  it "renders the label and preview value inside its own rect" do
    screen = TUI::Screen.new
    model = Widget.new("bolt")
    cell = TUI::Form::FormFieldCell(Widget).new(1, 1, 30, 1, sample_field, model, sample_popup(screen), 12)

    cell.composite(screen)

    screen.cell(0, 1).char.should eq("N") # "Name" label past the " " pointer at col 0
  end

  it "starts editing on Enter" do
    screen = TUI::Screen.new
    model = Widget.new("bolt")
    cell = TUI::Form::FormFieldCell(Widget).new(1, 1, 30, 1, sample_field, model, sample_popup(screen), 12)

    cell.handle_key(TUI::KeyEvent.new(TUI::Key::Enter)).should be_true
    cell.status_hint.should contain("commit")
  end

  it "commits a valid edit back through set" do
    screen = TUI::Screen.new
    model = Widget.new("bolt")
    cell = TUI::Form::FormFieldCell(Widget).new(1, 1, 30, 1, sample_field, model, sample_popup(screen), 12)

    cell.handle_key(TUI::KeyEvent.new(TUI::Key::Enter))
    cell.handle_key(TUI::KeyEvent.new(TUI::Key::Char, 'x'))
    cell.handle_key(TUI::KeyEvent.new(TUI::Key::Esc))

    model.name.should eq("boltx")
  end

  it "rejects a commit that fails the field's validator, leaving the model untouched" do
    screen = TUI::Screen.new
    model = Widget.new("bolt")
    field = sample_field(validator: ->(v : String) { !v.empty? })
    cell = TUI::Form::FormFieldCell(Widget).new(1, 1, 30, 1, field, model, sample_popup(screen), 12)

    cell.handle_key(TUI::KeyEvent.new(TUI::Key::Enter))
    4.times { cell.handle_key(TUI::KeyEvent.new(TUI::Key::Backspace)) }
    cell.handle_key(TUI::KeyEvent.new(TUI::Key::Backspace))
    cell.handle_key(TUI::KeyEvent.new(TUI::Key::Esc))

    model.name.should eq("bolt")
    cell.status_hint.should contain("commit") # still mid-edit
  end
end
