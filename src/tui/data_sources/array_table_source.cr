require "./table_data_source"

module TUI
  # Generic TableDataSource over an in-memory Array(T) — a substring
  # filter on one derived string per row, plus symbol-keyed sort
  # comparators, covers every hand-written array-backed TableDataSource
  # this library's own examples needed. Anything needing a richer filter
  # (multi-field, fuzzy) or a data source backed by something other than
  # a plain in-memory Array should still hand-write its own
  # TableDataSource — this covers the common case, not every case.
  #
  # `sort_keys` maps a Symbol to a (T, T) -> Int32 comparator rather than
  # a key-extractor (T -> _), since Crystal can't compare two values
  # pulled from a Hash whose value type is a union across heterogeneous
  # field types (e.g. String for one sort key, Float64 for another) —
  # a two-argument comparator sidesteps that entirely.
  class ArrayTableSource(T) < TableDataSource
    def initialize(@all : Array(T), @title : String, @columns : Array(TableColumn),
                   @filter_text : T -> String, @row : T -> TableRow,
                   @sort_keys : Hash(Symbol, (T, T) -> Int32) = {} of Symbol => (T, T) -> Int32)
      @filtered = @all
    end

    def columns : Array(TableColumn)
      @columns
    end

    def row(index : Int32) : TableRow
      @row.call(@filtered[index])
    end

    # The currently-filtered row's underlying model — the generic
    # replacement for a hand-written source's own `xxx_at(index)`.
    def item_at(index : Int32) : T
      @filtered[index]
    end

    def size : Int32
      @filtered.size
    end

    def title(filter : String, sort_key : Symbol) : String
      filter.empty? ? @title : "#{@title} (filter: #{filter})"
    end

    def sort_keys : Array(Symbol)
      @sort_keys.keys
    end

    def reload(filter : String, sort : Symbol) : Nil
      matches = @all.select { |item| filter.empty? || @filter_text.call(item).includes?(filter) }
      @filtered = if comparator = @sort_keys[sort]?
                    matches.sort { |left, right| comparator.call(left, right) }
                  else
                    matches
                  end
    end
  end
end
