require "./list_view"
require "../form/form_field"

module TUI
  # ListDataSource over a flat, static Array(FormEnumOption) — backs the
  # dropdown picker popup's option list. Filters by substring match on
  # each option's label; has no sort keys (a single flat list has
  # nothing to cycle through — ListView's own `keys.size > 1` guard
  # already makes the 's' key a safe no-op here).
  class OptionListSource < ListDataSource
    def initialize(@title : String, @options : Array(FormEnumOption))
      @filtered = @options
    end

    def size : Int32
      @filtered.size
    end

    def title(filter : String, sort_key : Symbol) : String
      filter.empty? ? @title : "#{@title} (filter: #{filter})"
    end

    def sort_keys : Array(Symbol)
      [] of Symbol
    end

    def reload(filter : String, sort : Symbol) : Nil
      @filtered = @options.select { |option| filter.empty? || option.label.downcase.includes?(filter.downcase) }
    end

    def option_at(index : Int32) : FormEnumOption
      @filtered[index]
    end
  end

  # Single-select option list for the dropdown picker — Enter (handled
  # by ListView's own nav-mode Enter case) fires `on_activate` with the
  # picked row's index INTO THE CURRENTLY FILTERED LIST — callers must
  # resolve it via `option_source.option_at(index)`, never by indexing
  # their own original (unfiltered) options array directly, since the
  # index is only meaningful relative to whatever's filtered right now.
  class OptionListView < ListView
    def initialize(@option_source : OptionListSource)
      super(@option_source)
    end

    def option_source : OptionListSource
      @option_source
    end

    # Moves the cursor to `index` — call after #reload, since #reload
    # always resets the cursor to 0 when it repopulates the filtered
    # list from the source.
    def seek(index : Int32) : Nil
      @cursor = index if index > 0
    end

    def row_content(index : Int32) : String
      @option_source.option_at(index).label
    end
  end

  # Multi-select option list for the dropdown picker. Space toggles the
  # focused row's membership, independent of cursor movement (same
  # interaction FlagsField already uses inline). Enter means "confirm
  # the whole current selection" rather than "pick this one row and
  # close" — a different signal than single-select's `on_activate`, so
  # it's reported via a dedicated `on_confirm` property instead of
  # overloading `on_activate`'s one-index payload.
  #
  # Selection is tracked by wire_value, not by list index — a filtered
  # row's index shifts as the filter changes, so indices are never a
  # stable identity for "is this option selected"; only the option's own
  # wire_value is.
  class MultiOptionListView < ListView
    # Fires on Enter with the full current selection's wire_values (see
    # #selected_wire_values) — the "confirm this whole set" signal
    # described above, kept separate from ListView#on_activate.
    property on_confirm : Proc(Set(String), Nil)?

    def initialize(@option_source : OptionListSource, initial : Set(String) = Set(String).new)
      super(@option_source)
      @selected = initial.dup
    end

    def selected_wire_values : Set(String)
      @selected
    end

    def row_content(index : Int32) : String
      option = @option_source.option_at(index)
      marker = @selected.includes?(option.wire_value) ? "[x]" : "[ ]"
      "#{marker} #{option.label}"
    end

    def status_hint : String
      if filter_active?
        " Type to filter  ↑↓:navigate  Enter:open detail  Esc:cancel search"
      else
        " ↑↓:navigate  Space:toggle  Enter:confirm  /:search"
      end
    end

    private def handle_nav_key(ev : KeyEvent, scroll : ScrollControl) : Bool
      case ev.key
      when Key::Enter
        @on_confirm.try &.call(@selected)
        true
      when Key::Char
        if ev.char == ' '
          toggle_focused
          true
        else
          super
        end
      else
        super
      end
    end

    private def toggle_focused : Nil
      return unless idx = selected_index
      wire_value = @option_source.option_at(idx).wire_value
      if @selected.includes?(wire_value)
        @selected.delete(wire_value)
      else
        @selected << wire_value
      end
    end
  end
end
