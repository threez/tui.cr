require "../spec_helper"

private class DefineWidget
  property name : String
  property active : String
  property color : String
  property age : String
  property tags : String

  def initialize(@name = "bolt", @active = "false", @color = "red", @age = "1.5", @tags = "0")
  end
end

private COLOR_OPTIONS = [
  TUI::FormEnumOption.new("Red", "red"),
  TUI::FormEnumOption.new("Green", "green"),
  TUI::FormEnumOption.new("Blue", "blue"),
]

private TAG_OPTIONS = [
  TUI::FormEnumOption.new("a", "a"),
  TUI::FormEnumOption.new("b", "b"),
]

TUI::Form.define(DEFINE_FIELDS, DefineWidget) do
  field :name
  field :active, bool: true
  field :color, dropdown: COLOR_OPTIONS
  field :tags, options: TAG_OPTIONS, flags: true, rows: 2
  field :age, label: "Age (custom)", validate: :float, error: "Age must be numeric"
  field :name, label: "Notes", rows: 4, edit: true
  field :name, label: "Notes (md)", rows: 4, markdown_edit: true
end

describe "TUI::Form.define" do
  it "auto-derives a Title Case label from the property name" do
    field = DEFINE_FIELDS.find(&.label.==("Name"))
    field.should_not be_nil
  end

  it "honors an explicit label: override" do
    field = DEFINE_FIELDS.find { |candidate| candidate.label == "Age (custom)" }
    field.should_not be_nil
  end

  it "binds get/set to the real named property, in both directions" do
    field = DEFINE_FIELDS.find!(&.label.==("Name"))
    model = DefineWidget.new(name: "imagemagick")

    field.get.call(model).should eq("imagemagick")

    field.set.call(model, "imagemagick7")
    model.name.should eq("imagemagick7")
  end

  it "defaults to an InputField when no kind kwarg is given" do
    field = DEFINE_FIELDS.find!(&.label.==("Name"))
    field.build.try(&.call).should be_a(TUI::InputField)
  end

  it "edit: true produces a ScrollableField(TextEdit)" do
    field = DEFINE_FIELDS.find!(&.label.==("Notes"))
    field.build.try(&.call).should be_a(TUI::ScrollableField(TUI::TextEdit))
    field.rows.should eq(4)
  end

  it "markdown_edit: true produces a ScrollableField(MarkdownEdit)" do
    field = DEFINE_FIELDS.find!(&.label.==("Notes (md)"))
    field.build.try(&.call).should be_a(TUI::ScrollableField(TUI::MarkdownEdit))
    field.rows.should eq(4)
  end

  it "bool: true produces a BoolField" do
    field = DEFINE_FIELDS.find!(&.label.==("Active"))
    field.build.try(&.call).should be_a(TUI::BoolField)
  end

  it "options: + flags: true produces a FlagsField and propagates rows:" do
    field = DEFINE_FIELDS.find!(&.label.==("Tags"))
    field.build.try(&.call).should be_a(TUI::FlagsField)
    field.rows.should eq(2)
  end

  it "dropdown: sets dropdown_options without dropdown_multi" do
    field = DEFINE_FIELDS.find!(&.label.==("Color"))
    field.dropdown_options.should eq(COLOR_OPTIONS)
    field.dropdown_multi.should be_false
    field.build.should be_nil
  end

  it "validate: :float maps to a working TUI::Validation proc" do
    field = DEFINE_FIELDS.find!(&.label.==("Age (custom)"))
    field.validator.try(&.call("abc")).should be_false
    field.validator.try(&.call("1.5")).should be_true
    field.error_message.should eq("Age must be numeric")
  end

  it "end-to-end: drives a real Form::Host exactly like a hand-written FieldSpec array would" do
    screen = TUI::Screen.new
    model = DefineWidget.new(name: "bolt", active: "false", color: "red")
    popup = TUI::Form::PopupHost.new(screen: screen, push: ->(_w : TUI::Widget) { nil }, pop: -> { nil })
    host = TUI::Form::Host(DefineWidget).new(1, 1, screen.cols, screen.rows - 1, DEFINE_FIELDS, model, popup)

    host.handle_key(TUI::KeyEvent.new(TUI::Key::Enter))
    host.handle_key(TUI::KeyEvent.new(TUI::Key::Char, 'x'))
    host.handle_key(TUI::KeyEvent.new(TUI::Key::Esc))

    model.name.should eq("boltx")

    host.handle_key(TUI::KeyEvent.new(TUI::Key::Tab)) # focus -> Active
    host.handle_key(TUI::KeyEvent.new(TUI::Key::Enter))
    host.handle_key(TUI::KeyEvent.new(TUI::Key::Char, ' '))
    host.handle_key(TUI::KeyEvent.new(TUI::Key::Enter))

    model.active.should eq("true")
  end

  it "pushes a dropdown popup for a dropdown-kind field built via the DSL" do
    screen = TUI::Screen.new
    model = DefineWidget.new
    pushed = [] of TUI::Widget
    popup = TUI::Form::PopupHost.new(screen: screen,
      push: ->(w : TUI::Widget) { pushed << w; nil },
      pop: -> { nil })
    host = TUI::Form::Host(DefineWidget).new(1, 1, screen.cols, screen.rows - 1, DEFINE_FIELDS, model, popup)

    2.times { host.handle_key(TUI::KeyEvent.new(TUI::Key::Tab)) } # Name -> Active -> Color
    host.handle_key(TUI::KeyEvent.new(TUI::Key::Enter))

    pushed.size.should eq(1)
    pushed.first.should be_a(TUI::Window)
  end
end
