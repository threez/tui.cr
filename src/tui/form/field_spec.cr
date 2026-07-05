require "./form_field"

module TUI
  module Form
    # Declares one field of a Form::Host(M) form: its label, how to build
    # the FormField that edits it, and how to read/write its value on the
    # bound model `M`. `get`/`set` are required (no default) so a
    # FieldSpec can never be constructed without a real binding to the
    # model — this is the mechanism, not a convention, that rules out a
    # field silently defaulting to a hardcoded value disconnected from
    # whatever model it's supposedly editing.
    #
    # `dropdown_options`/`dropdown_multi` opt a field out of the normal
    # `build`-a-FormField flow entirely — FormField's abstract contract
    # has no side-channel for "please push a popup," so a field with
    # `dropdown_options` set is instead driven by Form::Host directly via
    # TUI::DropdownPicker (see Form::Host#open_dropdown). `build` is
    # nilable and unused for dropdown fields.
    record FieldSpec(M),
      label : String,
      get : M -> String,
      set : (M, String) -> Nil,
      build : (-> FormField)? = nil,
      rows : Int32 = 1,
      validator : (String -> Bool)? = nil,
      error_message : String = "Invalid value",
      dropdown_options : Array(FormEnumOption)? = nil,
      dropdown_multi : Bool = false
  end
end
