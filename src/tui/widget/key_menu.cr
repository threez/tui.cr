require "../core/keys"

module TUI
  # An ordered registry of {trigger, label, action} bindings backing
  # BOTH key dispatch and the status-bar hint describing those same
  # bindings, so the two can't drift — #hint is generated from exactly
  # the data #dispatch uses, gated by the same `when:` predicate.
  # Deliberately excludes MouseClick: a click has no stable "label" and
  # needs widget-specific coordinate math, which stays where it already
  # lives (Window/SplitWindow).
  class KeyMenu
    # One registered binding: `trigger` is the key/char #dispatch matches
    # against, `label` is the exact text #hint shows for it, `when` an
    # optional guard that must return true for the binding to be active
    # (nil means always active), `action` the callback #dispatch invokes
    # on a match.
    record Binding,
      trigger : Key | Char,
      label : String,
      when : (-> Bool)?,
      action : KeyEvent -> Nil

    def initialize
      @bindings = [] of Binding
    end

    # `action` receives the matched KeyEvent — ignore it (`{ do_thing }`)
    # if the binding doesn't need it. Matching always consumes the event;
    # a binding that wants to conditionally decline should use `when:`.
    def bind(trigger : Key | Char, label : String, when condition : (-> Bool)? = nil, &action : KeyEvent -> _) : Nil
      @bindings << Binding.new(trigger, label, condition, ->(ev : KeyEvent) { action.call(ev); nil })
    end

    # Tries every active binding in registration order. Returns true
    # (consumed) on the first match; false if nothing matched.
    def dispatch(ev : KeyEvent) : Bool
      @bindings.each do |binding|
        next unless matches?(binding, ev)
        if w = binding.when
          next unless w.call
        end
        binding.action.call(ev)
        return true
      end
      false
    end

    # Ordered, space-joined hint text for every currently-active binding
    # (when: true or absent) — same data + same gate as #dispatch, so
    # dispatch and displayed hint can never drift apart.
    def hint : String
      active = @bindings.select { |binding| (w = binding.when).nil? || w.call }
      " " + active.map(&.label).join("  ")
    end

    private def matches?(b : Binding, ev : KeyEvent) : Bool
      case trig = b.trigger
      in Char
        ev.key == Key::Char && ev.char == trig
      in Key
        ev.key == trig
      end
    end
  end
end
