require "../widgets/cell"

module TUI
  # One label/value row in a DetailView. `label` is plain text; `value` is
  # a styled Cell so a row can carry its own color/emphasis independent of
  # DetailView's own rendering (bold labels, dimmed wrap markers, etc).
  record DetailLine, label : String, value : Cell do
    def self.new(label : String, value : String)
      new(label, Cell.new(value))
    end
  end

  abstract class DetailDataSource
    abstract def title(id : String) : String
    abstract def lines(id : String, expansions : Set(Symbol)) : Array(DetailLine)
    abstract def toggles : Array(Symbol)

    # Human label for the toggle key bound to `sym` (e.g. "dependents"
    # for :rdeps) — drives DetailView's status hint, so the letters shown
    # to the user and the letters that actually work can never drift.
    abstract def toggle_label(sym : Symbol) : String
  end
end
