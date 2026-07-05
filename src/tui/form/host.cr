require "../widget/widget"
require "../core/term"
require "../nav/nav_stack"
require "./form_field"
require "./field_spec"
require "./popup_host"
require "../widgets/dropdown_picker"

module TUI
  module Form
    # Drives a list of FieldSpec(M) against a bound model `M`: renders each
    # field's label/preview, moves focus with Up/Down, and edits one field
    # at a time via whichever concrete FormField that field's `build`
    # constructs (or, for a `dropdown_options` field, via a
    # TUI::DropdownPicker popup pushed through `popup` instead — FormField's
    # abstract contract has no side-channel to ask its host to push a
    # popup, so a dropdown field bypasses the FormField/@editor flow
    # entirely rather than stretching that contract for the minority of
    # fields that need it).
    #
    # `field.get`/`field.set` are the only way this class reads or writes
    # `@model` — a FieldSpec cannot exist without both, so every field
    # rendered or committed here is guaranteed to be backed by a real
    # accessor on `M`, never a value invented independently of the model.
    class Host(M) < Widget
      # Default column width reserved for a field's label, before the value
      # column starts — override via #initialize's `label_width` for
      # consumers with longer labels.
      DEFAULT_LABEL_WIDTH = 12
      # Default floor: the value column must keep at least this much width
      # before any of it is given up to an inline error message — below
      # this floor, the error is dropped rather than squeezing the value
      # further (see #render_editing_field). Override via #initialize's
      # `min_value_width`.
      DEFAULT_MIN_VALUE_WIDTH = 20
      # Default upper bound on how much value-column width an inline error
      # message may claim, even if there'd be room to give it more.
      # Override via #initialize's `max_error_width`.
      DEFAULT_MAX_ERROR_WIDTH = 40

      # Applied to a field's label when it has focus but no validation
      # error (see #render_field/#render_editing_field).
      property label_style : Style = Style.new(bold: true)

      # Applied to a field's label while it's being edited and currently
      # has a validation error — previously required manually nesting
      # `Term.fg(:red, Term.bold(...))`; now one composed Style.
      property label_error_style : Style = Style.new(bold: true, fg: TUI.color(:red))

      # Applied to the inline validation error message shown beside a
      # field (see #render_editing_field).
      property error_style : Style = Style.new(fg: TUI.color(:red))

      # Applied to the box border drawn by #render.
      property border_style : Style = Style.new(fg: TUI.color(:gray))

      def initialize(x : Int32, y : Int32, width : Int32, height : Int32,
                     @fields : Array(FieldSpec(M)), @model : M, @popup : PopupHost,
                     @title : String = "Edit", @label_width : Int32 = DEFAULT_LABEL_WIDTH,
                     @min_value_width : Int32 = DEFAULT_MIN_VALUE_WIDTH,
                     @max_error_width : Int32 = DEFAULT_MAX_ERROR_WIDTH)
        super(x, y, width, height)
        @focus_index = 0
        @editor = nil.as(FormField?)
        @error = nil.as(String?)
      end

      # Sizes and positions a Host to fill the screen below the status bar
      # row — see Window.full_screen for the same reasoning.
      def self.full_screen(screen : Screen, fields : Array(FieldSpec(M)), model : M,
                           popup : PopupHost, title : String = "Edit",
                           label_width : Int32 = DEFAULT_LABEL_WIDTH,
                           min_value_width : Int32 = DEFAULT_MIN_VALUE_WIDTH,
                           max_error_width : Int32 = DEFAULT_MAX_ERROR_WIDTH) : Host(M)
        new(1, 1, screen.cols, screen.rows - 1, fields, model, popup, title,
          label_width, min_value_width, max_error_width)
      end

      # Builds a PopupHost from an app's actual NavStack(Widget), so a host
      # app doesn't need to hand-write the push/pop proc wiring itself.
      def self.popup_host(screen : Screen, nav : NavStack(Widget)) : PopupHost
        PopupHost.new(screen: screen, push: ->(w : Widget) { nav.push(w) }, pop: -> { nav.pop })
      end

      def render : Nil
        @buffer.box(0, 0, height, width, title: @title, style: border_style)
        row = 1
        @fields.each_with_index do |field, i|
          break if row >= height - 1
          render_field(field, i, row)
          row += field.rows
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
          " ↑↓:navigate  Enter:edit"
        end
      end

      private def render_field(field : FieldSpec(M), index : Int32, row : Int32) : Nil
        focused = index == @focus_index
        pointer = focused ? "▸" : " "
        label = Term.fit("#{pointer}#{field.label}", @label_width + 1)
        value_col = @label_width + 3

        if (editor = @editor) && focused
          render_editing_field(field, editor, label, row, value_col)
          return
        end

        @buffer.set(row, 1, focused ? Term.apply(label_style, label) : label)

        if options = field.dropdown_options
          render_dropdown_preview(field, options, row, value_col)
        else
          render_field_preview(field, row, value_col)
        end
      end

      private def render_editing_field(field : FieldSpec(M), editor : FormField, label : String, row : Int32, value_col : Int32) : Nil
        error = @error
        styled_label = error ? Term.apply(label_error_style, label) : Term.apply(label_style, label)
        @buffer.set(row, 1, styled_label)

        value_width = width - value_col - 1
        if error
          error_width = [value_width - @min_value_width, @max_error_width].min
          if error_width > 0
            value_width -= error_width
            editor.render(@buffer, row, value_col, value_width, height: field.rows)
            error_col = value_col + value_width + 1
            @buffer.set(row, error_col, Term.fit(Term.apply(error_style, "─ #{error}"), error_width))
            return
          end
        end

        editor.render(@buffer, row, value_col, value_width, height: field.rows)
      end

      private def render_dropdown_preview(field : FieldSpec(M), options : Array(FormEnumOption), row : Int32, value_col : Int32) : Nil
        current = field.get.call(@model)
        labels = if field.dropdown_multi
                   selected = decode_wire_values(current)
                   options.select { |option| selected.includes?(option.wire_value) }.map(&.label)
                 else
                   [options.find { |option| option.wire_value == current }.try(&.label) || ""]
                 end
        text = labels.empty? ? "(none)" : labels.join(", ")
        @buffer.set(row, value_col, Term.fit(text, width - value_col - 1))
      end

      private def render_field_preview(field : FieldSpec(M), row : Int32, value_col : Int32) : Nil
        build = field.build
        return unless build
        preview = build.call
        preview.start(field.get.call(@model))

        if preview.is_a?(BoolField)
          @buffer.set(row, value_col, Term.fit(field.get.call(@model), width - value_col - 1))
        else
          preview.render(@buffer, row, value_col, width - value_col - 1, height: field.rows, focused: false)
        end
      end

      private def handle_nav_key(ev : KeyEvent) : Bool
        case ev.key
        when Key::Up
          @focus_index = [@focus_index - 1, 0].max
          true
        when Key::Down
          @focus_index = [@focus_index + 1, @fields.size - 1].min
          true
        when Key::Enter
          start_editing
          true
        else
          false
        end
      end

      private def start_editing : Nil
        field = @fields[@focus_index]
        @error = nil
        if options = field.dropdown_options
          open_dropdown(field, options)
        elsif build = field.build
          editor = build.call
          editor.start(field.get.call(@model))
          @editor = editor
        end
      end

      private def open_dropdown(field : FieldSpec(M), options : Array(FormEnumOption)) : Nil
        if field.dropdown_multi
          initial = decode_wire_values(field.get.call(@model))
          result = DropdownPicker.centered_multi(@popup.screen, field.label, options, initial)
          result[:window].border_style = border_style
          result[:list].on_confirm = ->(selected : Set(String)) {
            field.set.call(@model, encode_wire_values(selected))
            @popup.pop.call
            nil
          }
        else
          current_index = options.index { |option| option.wire_value == field.get.call(@model) } || 0
          result = DropdownPicker.centered(@popup.screen, field.label, options, current_index)
          result[:window].border_style = border_style
          list = result[:list]
          list.on_activate = ->(index : Int32) {
            field.set.call(@model, list.option_source.option_at(index).wire_value)
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
        field = @fields[@focus_index]
        if (validator = field.validator) && !validator.call(editor.value)
          @error = field.error_message
          return
        end
        field.set.call(@model, editor.value)
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
