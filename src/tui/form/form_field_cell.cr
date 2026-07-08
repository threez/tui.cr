require "../widget/widget"
require "./field_spec"
require "./popup_host"
require "../widgets/dropdown_picker"

module TUI
  module Form
    # One form row as its own composited Widget: a label plus whichever
    # FormField edit session `field.build` constructs (or, for a
    # `dropdown_options` field, a TUI::DropdownPicker popup pushed
    # through `popup` instead — see #start_editing). Grid
    # (src/tui/layout/grid.cr) positions and focuses one of these per
    # field; Form::Host builds one FormFieldCell per FieldSpec and
    # attaches them into its internal Grid, rather than looping over
    # `@fields` and hand-computing row/column coordinates itself the way
    # it used to.
    #
    # `field.get`/`field.set` are the only way this class reads or
    # writes `@model` — a FieldSpec cannot exist without both, so every
    # cell rendered or committed here is guaranteed to be backed by a
    # real accessor on `M`, never a value invented independently of the
    # model. This mirrors the invariant Form::Host itself used to state.
    class FormFieldCell(M) < Widget
      property label_style : Style = Style.new(bold: true)
      property label_error_style : Style = Style.new(bold: true, fg: TUI.color(:red))
      property error_style : Style = Style.new(fg: TUI.color(:red))

      DEFAULT_MIN_VALUE_WIDTH = 20
      DEFAULT_MAX_ERROR_WIDTH = 40

      # Applied to a dropdown popup's own border when this cell opens one
      # (see #open_dropdown) — passed in from Form::Host's own
      # border_style so a dropdown popup visually matches the form it
      # was opened from, the same styling Form::Host applied directly
      # before this logic moved into FormFieldCell.
      property popup_border_style : Style = Style.new(fg: TUI.color(:gray))

      def initialize(x : Int32, y : Int32, width : Int32, height : Int32,
                     @field : FieldSpec(M), @model : M, @popup : PopupHost,
                     @label_width : Int32, @min_value_width : Int32 = DEFAULT_MIN_VALUE_WIDTH,
                     @max_error_width : Int32 = DEFAULT_MAX_ERROR_WIDTH)
        super(x, y, width, height)
        @editor = nil.as(FormField?)
        @error = nil.as(String?)
      end

      def render : Nil
        value_col = @label_width + 3
        label = Term.fit("#{focused? ? "▸" : " "}#{@field.label}", @label_width + 1)

        if editor = @editor
          render_editing(editor, label, value_col)
          return
        end

        @buffer.set(0, 0, focused? ? Term.apply(label_style, label) : label)
        if options = @field.dropdown_options
          render_dropdown_preview(options, value_col)
        else
          render_field_preview(value_col)
        end
      end

      def handle_key(ev : KeyEvent) : Bool
        if editor = @editor
          handle_editor_key(editor, ev)
        else
          handle_nav_key(ev)
        end
      end

      def status_hint : String
        if editor = @editor
          editor.status_hint
        else
          " Enter:edit"
        end
      end

      private def render_editing(editor : FormField, label : String, value_col : Int32) : Nil
        error = @error
        styled_label = error ? Term.apply(label_error_style, label) : Term.apply(label_style, label)
        @buffer.set(0, 0, styled_label)

        value_width = width - value_col - 1
        if error
          error_width = [value_width - @min_value_width, @max_error_width].min
          if error_width > 0
            value_width -= error_width
            editor.render(@buffer, 0, value_col, value_width, height: height)
            error_col = value_col + value_width + 1
            @buffer.set(0, error_col, Term.fit(Term.apply(error_style, "─ #{error}"), error_width))
            return
          end
        end

        editor.render(@buffer, 0, value_col, value_width, height: height)
      end

      private def render_dropdown_preview(options : Array(FormEnumOption), value_col : Int32) : Nil
        current = @field.get.call(@model)
        labels = if @field.dropdown_multi
                   selected = decode_wire_values(current)
                   options.select { |option| selected.includes?(option.wire_value) }.map(&.label)
                 else
                   [options.find { |option| option.wire_value == current }.try(&.label) || ""]
                 end
        text = labels.empty? ? "(none)" : labels.join(", ")
        @buffer.set(0, value_col, Term.fit(text, width - value_col - 1))
      end

      private def render_field_preview(value_col : Int32) : Nil
        build = @field.build
        return unless build
        preview = build.call
        preview.start(@field.get.call(@model))

        if preview.is_a?(BoolField)
          @buffer.set(0, value_col, Term.fit(@field.get.call(@model), width - value_col - 1))
        else
          preview.render(@buffer, 0, value_col, width - value_col - 1, height: height, focused: false)
        end
      end

      private def handle_nav_key(ev : KeyEvent) : Bool
        return false unless ev.key == Key::Enter
        start_editing
        true
      end

      private def start_editing : Nil
        @error = nil
        if options = @field.dropdown_options
          open_dropdown(options)
        elsif build = @field.build
          editor = build.call
          editor.start(@field.get.call(@model))
          @editor = editor
        end
      end

      private def open_dropdown(options : Array(FormEnumOption)) : Nil
        if @field.dropdown_multi
          initial = decode_wire_values(@field.get.call(@model))
          result = DropdownPicker.centered_multi(@popup.screen, @field.label, options, initial)
          result[:window].border_style = popup_border_style
          result[:list].on_confirm = ->(selected : Set(String)) {
            @field.set.call(@model, encode_wire_values(selected))
            @popup.pop.call
            nil
          }
        else
          current_index = options.index { |option| option.wire_value == @field.get.call(@model) } || 0
          result = DropdownPicker.centered(@popup.screen, @field.label, options, current_index)
          result[:window].border_style = popup_border_style
          list = result[:list]
          list.on_activate = ->(index : Int32) {
            @field.set.call(@model, list.option_source.option_at(index).wire_value)
            @popup.pop.call
            nil
          }
        end
        @popup.push.call(result[:window].as(Widget))
      end

      private def handle_editor_key(editor : FormField, ev : KeyEvent) : Bool
        result = editor.handle_key(ev)
        case result
        when :commit
          commit_editor(editor)
        when :cancel
          @editor = nil
        end
        true
      end

      private def commit_editor(editor : FormField) : Nil
        if (validator = @field.validator) && !validator.call(editor.value)
          @error = @field.error_message
          return
        end
        @field.set.call(@model, editor.value)
        @error = nil
        @editor = nil
      end

      private def decode_wire_values(raw : String) : Set(String)
        raw.split(',', remove_empty: true).to_set
      end

      private def encode_wire_values(selected : Set(String)) : String
        selected.to_a.sort.join(',')
      end
    end
  end
end
