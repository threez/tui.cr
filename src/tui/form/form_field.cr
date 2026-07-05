require "../widget/widget"
require "../widgets/cell"

module TUI
  # One choice in an EnumField/FlagsField picker: `label` is what's shown
  # on screen, `wire_value` is what gets persisted (see FormField#value)
  # and what a FieldSpec's current value is matched against on #start.
  record FormEnumOption, label : String, wire_value : String

  # A single field's in-progress edit state, plus the key handling and
  # rendering for whichever concrete kind it is. Replaces having a widget
  # juggle several independent boolean "am I editing this kind of field"
  # flags — a widget owns at most one FormField at a time, and "is
  # something being edited" is simply `editor != nil`.
  #
  # Text/Bool/Enum/Flags share almost no mechanics (Text owns
  # cursor/scroll/line-edit state, Bool a single toggle flag, Enum/Flags
  # an options list with different selection semantics), so each kind is
  # its own concrete subclass rather than one class branching on an enum
  # — mirrors this library's ListDataSource/DetailDataSource convention
  # of an abstract protocol implemented independently per concern, not a
  # deep shared hierarchy.
  #
  # Esc semantics intentionally differ by kind, matching the source
  # pattern this generalizes: Text and Bool edits commit on Esc (there is
  # no discard-in-place gesture for them); Enum and Flags pickers cancel
  # on Esc without writing back, since a picker with nothing selected yet
  # has no sensible "commit" value.
  abstract class FormField
    # Loads a persisted wire-value string into this field's edit state.
    abstract def start(current_value : String) : Nil

    # Returns :commit or :cancel once the edit finishes; nil while it's
    # still in progress (the key was consumed either way).
    abstract def handle_key(ev : KeyEvent) : Symbol?

    # The composed value after a :commit result.
    abstract def value : String

    # Draws this field's current edit state. `height` bounds how many
    # buffer rows this field may draw into. `focused` gates any
    # keyboard-cursor decoration that should be suppressed when
    # rendering a persisted value outside an active edit session (only
    # FlagsField uses this — see its #render).
    abstract def render(buffer : Buffer, y : Int32, x : Int32, width : Int32, height : Int32 = 1, focused : Bool = true) : Nil

    # Fragment of a host's status-bar hint describing this field's own
    # key bindings while it's being edited — owned here (rather than
    # left for a host to re-derive per kind) so the bindings shown to
    # the user can never drift from what #handle_key actually does.
    abstract def status_hint : String
  end
end

require "./text_field"
require "./bool_field"
require "./enum_field"
require "./flags_field"
