require "./field_spec"
require "../validation"

module TUI
  module Form
    # Block-DSL sugar over FieldSpec(M) construction. Must be called as a
    # bare top-level statement (not the right-hand side of an assignment)
    # — the macro itself emits both a helper class declaration and the
    # `name = HelperClass.build` assignment as two sibling top-level
    # statements, since Crystal disallows a macro emitting a `class`
    # declaration from expression/value position ("can't declare class
    # dynamically").
    #
    # Every `field` call still ends up as a literal `m.prop`/`m.prop = v`
    # reference inside the generated `self.build` method — a property
    # name that doesn't exist on the model is an ordinary Crystal
    # "undefined method" compile error, not a silent no-op, PROVIDED the
    # constant this macro assigns is actually read somewhere (Crystal
    # skips type-checking of an unread top-level constant's initializer
    # entirely — this macro can't change that ordinary Crystal semantic,
    # so a `TUI::Form.define` block whose target constant is never
    # referenced elsewhere would not be type-checked; every real call
    # site passes the result straight into `Form::Host`, which reads it,
    # so this is a non-issue in practice, but it means a spec exercising
    # this safety guarantee must actually call `.get`/`.set`, not just
    # assert "it compiles").
    macro define(name, model_type, &block)
      class Define_{{ model_type.id }}_{{ name.id }}
        def self.build : Array(::TUI::Form::FieldSpec({{ model_type }}))
          list = [] of ::TUI::Form::FieldSpec({{ model_type }})
          {% for call in (block.body.is_a?(Expressions) ? block.body.expressions : [block.body]) %}
            {% if call.is_a?(Call) && call.name.id == "field".id %}
              {% prop = call.args[0] %}
              {% nargs = call.named_args %}
              {% named = (nargs.is_a?(ArrayLiteral) || nargs.is_a?(TupleLiteral)) ? nargs : [] of Nil %}
              {% label_node = named.find { |arg| arg.name.id == "label".id } %}
              {% rows_node = named.find { |arg| arg.name.id == "rows".id } %}
              {% options_node = named.find { |arg| arg.name.id == "options".id } %}
              {% flags_node = named.find { |arg| arg.name.id == "flags".id } %}
              {% bool_node = named.find { |arg| arg.name.id == "bool".id } %}
              {% validate_node = named.find { |arg| arg.name.id == "validate".id } %}
              {% error_node = named.find { |arg| arg.name.id == "error".id } %}
              {% dropdown_node = named.find { |arg| arg.name.id == "dropdown".id } %}
              {% multi_node = named.find { |arg| arg.name.id == "multi".id } %}

              {% if options_node && dropdown_node %}
                {% call.raise "field #{prop}: options: and dropdown: are mutually exclusive" %}
              {% end %}

              {% label_value = label_node ? label_node.value : prop.id.stringify.split('_').map(&.capitalize).join(" ") %}

              list << ::TUI::Form::FieldSpec({{ model_type }}).new(
                {{ label_value }},
                get: ->(m : {{ model_type }}) { m.{{ prop.id }} },
                set: ->(m : {{ model_type }}, v : String) { m.{{ prop.id }} = v; nil },
                {% if rows_node %} rows: {{ rows_node.value }}, {% end %}
                {% if error_node %} error_message: {{ error_node.value }}, {% end %}
                {% if validate_node %}
                  {% if validate_node.value.is_a?(SymbolLiteral) %}
                    validator: ->::TUI::Validation.valid_{{ validate_node.value.id }}?(String),
                  {% else %}
                    validator: {{ validate_node.value }},
                  {% end %}
                {% end %}
                {% if dropdown_node %}
                  dropdown_options: {{ dropdown_node.value }},
                  {% if multi_node %} dropdown_multi: {{ multi_node.value }}, {% end %}
                {% elsif flags_node %}
                  build: -> { ::TUI::FlagsField.new({{ options_node.value }}).as(::TUI::FormField) },
                {% elsif options_node %}
                  build: -> { ::TUI::EnumField.new({{ options_node.value }}).as(::TUI::FormField) },
                {% elsif bool_node %}
                  build: -> { ::TUI::BoolField.new.as(::TUI::FormField) },
                {% else %}
                  build: -> { ::TUI::TextField.new.as(::TUI::FormField) },
                {% end %}
              )
            {% end %}
          {% end %}
          list
        end
      end
      {{ name.id }} = Define_{{ model_type.id }}_{{ name.id }}.build
    end
  end
end
