require "../spec_helper"

private class Widget
  property name : String

  def initialize(@name)
  end
end

describe TUI::Form::FieldSpec do
  it "reads through the required get proc" do
    field = TUI::Form::FieldSpec(Widget).new("Name",
      get: ->(m : Widget) { m.name }, set: ->(m : Widget, v : String) { m.name = v; nil })
    model = Widget.new("bolt")

    field.get.call(model).should eq("bolt")
  end

  it "writes through the required set proc" do
    field = TUI::Form::FieldSpec(Widget).new("Name",
      get: ->(m : Widget) { m.name }, set: ->(m : Widget, v : String) { m.name = v; nil })
    model = Widget.new("bolt")

    field.set.call(model, "nut")

    model.name.should eq("nut")
  end

  it "defaults rows to 1 and dropdown_multi to false" do
    field = TUI::Form::FieldSpec(Widget).new("Name",
      get: ->(m : Widget) { m.name }, set: ->(m : Widget, v : String) { m.name = v; nil })

    field.rows.should eq(1)
    field.dropdown_multi.should be_false
    field.dropdown_options.should be_nil
    field.build.should be_nil
    field.validator.should be_nil
  end
end
