require "./detail_data_source"

module TUI
  # Generic DetailDataSource over an in-memory Array(T), id-keyed by a
  # single string-valued property — the direct Detail-side analog of
  # ArrayTableSource(T) for TableDataSource. Simpler than ArrayTableSource
  # since DetailDataSource has no filter/sort/size/reload contract to
  # replicate — just "given an id and the current toggle state, produce
  # label/value rows."
  class ArrayDetailSource(T) < DetailDataSource
    def initialize(@all : Array(T), @id_key : T -> String,
                   @lines : T -> Array(DetailLine),
                   @toggle_lines : Hash(Symbol, (T -> Array(DetailLine))) = {} of Symbol => (T -> Array(DetailLine)),
                   @toggle_labels : Hash(Symbol, String) = {} of Symbol => String)
    end

    def title(id : String) : String
      id
    end

    def lines(id : String, expansions : Set(Symbol)) : Array(DetailLine)
      item = @all.find { |candidate| @id_key.call(candidate) == id }
      return [] of DetailLine unless item

      result = @lines.call(item)
      @toggle_lines.each do |sym, proc|
        result += proc.call(item) if expansions.includes?(sym)
      end
      result
    end

    def toggles : Array(Symbol)
      @toggle_lines.keys
    end

    def toggle_label(sym : Symbol) : String
      @toggle_labels[sym]? || sym.to_s
    end
  end
end
