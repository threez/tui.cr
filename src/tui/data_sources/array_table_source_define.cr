require "./array_table_source"

module TUI
  class ArrayTableSource(T)
    # Block-DSL sugar over ArrayTableSource(T) construction. Unlike
    # Form.define, this macro does NOT auto-assign a constant to the
    # built source — Crystal disallows declaring a class inside a `def`
    # body ("can't define class inside def"), so a caller wanting a fresh
    # ArrayTableSource per call (e.g. one per page, so Table view and
    # Split window don't share filter/sort state) must call this macro
    # once at the top level to declare a named builder class, then call
    # that class's own `.build(all)` from a plain function whenever it
    # needs a new instance:
    #
    #   TUI::ArrayTableSource.define(PackageSourceBuilder, Package) do
    #     title "Packages"
    #     filter_by :name
    #     column :name, "Name", width: 10..20, expand: true
    #     column :size_mb, "Size (MB)", width: 6..10, align: :right, sort: true
    #   end
    #
    #   def build_package_source : TUI::ArrayTableSource(Package)
    #     PackageSourceBuilder.build(FAKE_PACKAGES)
    #   end
    #
    # Column cell styling avoids macro-time type introspection (Crystal's
    # `instance_vars` reflection only works inside a `def` body, not at
    # macro-expansion time of a single `column` call) by generating a
    # runtime `value.class.name.downcase` lookup instead — e.g.
    # `Float64.name.downcase == "float64"`, matching TypeStyle's own
    # case-when keys exactly. `sort: true` still generates a two-argument
    # comparator (`a.prop <=> b.prop || 0`), not a key-extractor, per
    # ArrayTableSource(T)'s own comparator-based sort_keys contract.
    macro define(name, model_type, &block)
      class {{ name.id }}
        def self.build(all : Array({{ model_type }})) : ::TUI::ArrayTableSource({{ model_type }})
          columns = [] of ::TUI::TableColumn
          cell_procs = [] of {{ model_type }} -> ::TUI::Cell
          sort_keys = {} of Symbol => ({{ model_type }}, {{ model_type }}) -> Int32
          title_value = ""
          filter_text_proc = ->(item : {{ model_type }}) { "" }

          {% for call in (block.body.is_a?(Expressions) ? block.body.expressions : [block.body]) %}
            {% if call.is_a?(Call) && call.name.id == "title".id %}
              title_value = {{ call.args[0] }}
            {% elsif call.is_a?(Call) && call.name.id == "filter_by".id %}
              {% filter_prop = call.args[0] %}
              filter_text_proc = ->(item : {{ model_type }}) { item.{{ filter_prop.id }}.to_s }
            {% elsif call.is_a?(Call) && call.name.id == "column".id %}
              {% prop = call.args[0] %}
              {% header = call.args[1] %}
              {% nargs = call.named_args %}
              {% named = (nargs.is_a?(ArrayLiteral) || nargs.is_a?(TupleLiteral)) ? nargs : [] of Nil %}
              {% width_node = named.find { |arg| arg.name.id == "width".id } %}
              {% expand_node = named.find { |arg| arg.name.id == "expand".id } %}
              {% align_node = named.find { |arg| arg.name.id == "align".id } %}
              {% sort_node = named.find { |arg| arg.name.id == "sort".id } %}

              columns << ::TUI::TableColumn.new(
                {{ header }},
                {{ width_node ? width_node.value.begin : 6 }},
                {{ width_node ? width_node.value.end : 10 }},
                {% if expand_node %} expand: {{ expand_node.value }}, {% end %}
                {% if align_node %} align: ({{ align_node.value }} == :right ? ::TUI::Align::Right : ::TUI::Align::Left), {% end %}
              )
              cell_procs << ->(item : {{ model_type }}) {
                value = item.{{ prop.id }}
                ::TUI::Cell.new(value.to_s, style: ::TUI::TypeStyle.for(value.class.name.downcase, ""))
              }
              {% if sort_node %}
                sort_keys[{{ prop }}] = ->(a : {{ model_type }}, b : {{ model_type }}) { a.{{ prop.id }} <=> b.{{ prop.id }} || 0 }
              {% end %}
            {% end %}
          {% end %}

          row_proc = ->(item : {{ model_type }}) { ::TUI::TableRow.new(cells: cell_procs.map { |cell_proc| cell_proc.call(item) }) }

          ::TUI::ArrayTableSource({{ model_type }}).new(
            all, title_value, columns,
            filter_text: filter_text_proc, row: row_proc, sort_keys: sort_keys
          )
        end
      end
    end
  end
end
