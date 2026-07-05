require "./array_detail_source"

module TUI
  class ArrayDetailSource(T)
    # Block-DSL sugar over ArrayDetailSource(T) construction — the
    # Detail-side analog of TUI::Form.define (same "auto-assign the
    # built value straight to a caller-named constant" shape), not of
    # ArrayTableSource.define. Unlike ArrayTableSource, a single
    # ArrayDetailSource instance has no independent per-page state (no
    # filter, no sort, no swapped-in data) — one shared instance covers
    # every consumer, so there's no need for ArrayTableSource.define's
    # named-builder-class indirection (that indirection exists there
    # solely because Crystal disallows declaring a class inside a def
    # body, and Table view/Split window each need their own independent
    # ArrayTableSource instance — neither constraint applies here).
    #
    #   TUI::ArrayDetailSource.define(PACKAGE_DETAIL_SOURCE, Package, FAKE_PACKAGES) do
    #     id_key :name
    #     line :name, "Name"
    #     line :size_mb, "Size", suffix: " MB"
    #     toggle :description, "description" do
    #       line :description, "Description"
    #     end
    #   end
    #
    # `all` is an ordinary (non-block) macro argument — the data array
    # must already exist as a top-level constant by the time this call
    # executes textually.
    macro define(name, model_type, all, &block)
      class Define_{{ model_type.id }}_{{ name.id }}
        def self.build(all : Array({{ model_type }})) : ::TUI::ArrayDetailSource({{ model_type }})
          base_lines = [] of {{ model_type }} -> ::TUI::DetailLine
          toggle_lines = {} of Symbol => ({{ model_type }} -> Array(::TUI::DetailLine))
          toggle_labels = {} of Symbol => String
          id_key_proc = ->(item : {{ model_type }}) { item.to_s }

          {% for call in (block.body.is_a?(Expressions) ? block.body.expressions : [block.body]) %}
            {% if call.is_a?(Call) && call.name.id == "id_key".id %}
              {% prop = call.args[0] %}
              id_key_proc = ->(item : {{ model_type }}) { item.{{ prop.id }}.to_s }
            {% elsif call.is_a?(Call) && call.name.id == "line".id %}
              {% prop = call.args[0] %}
              {% header = call.args[1] %}
              {% nargs = call.named_args %}
              {% named = (nargs.is_a?(ArrayLiteral) || nargs.is_a?(TupleLiteral)) ? nargs : [] of Nil %}
              {% suffix_node = named.find { |arg| arg.name.id == "suffix".id } %}
              base_lines << ->(item : {{ model_type }}) {
                {% if suffix_node %}
                  ::TUI::DetailLine.new({{ header }}, "#{item.{{ prop.id }}}" + {{ suffix_node.value }})
                {% else %}
                  ::TUI::DetailLine.new({{ header }}, "#{item.{{ prop.id }}}")
                {% end %}
              }
            {% elsif call.is_a?(Call) && call.name.id == "toggle".id %}
              {% sym = call.args[0] %}
              {% label = call.args[1] %}
              toggle_labels[{{ sym }}] = {{ label }}
              toggle_lines[{{ sym }}] = ->(item : {{ model_type }}) {
                lines = [] of ::TUI::DetailLine
                {% if call.block %}
                  {% for inner in (call.block.body.is_a?(Expressions) ? call.block.body.expressions : [call.block.body]) %}
                    {% if inner.is_a?(Call) && inner.name.id == "line".id %}
                      {% iprop = inner.args[0] %}
                      {% iheader = inner.args[1] %}
                      lines << ::TUI::DetailLine.new({{ iheader }}, "#{item.{{ iprop.id }}}")
                    {% end %}
                  {% end %}
                {% end %}
                lines
              }
            {% end %}
          {% end %}

          ::TUI::ArrayDetailSource({{ model_type }}).new(
            all,
            id_key: id_key_proc,
            lines: ->(item : {{ model_type }}) { base_lines.map(&.call(item)) },
            toggle_lines: toggle_lines,
            toggle_labels: toggle_labels,
          )
        end
      end
      {{ name.id }} = Define_{{ model_type.id }}_{{ name.id }}.build({{ all }})
    end
  end
end
