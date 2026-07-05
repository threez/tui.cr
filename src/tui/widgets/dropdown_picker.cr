require "../widget/window"
require "./option_list"

module TUI
  # Sizing/construction factory for a centered, content-sized Window
  # hosting a searchable option list — the dropdown-picker counterpart
  # to Popup.centered, except height tracks option count instead of a
  # fixed single message line, and the "message" is an interactive list
  # rather than static text. Push the returned Window via NavStack#push
  # directly (same escape hatch Popup itself documents and uses), not
  # Runtime#push, so it keeps this computed size instead of being forced
  # full-screen.
  module DropdownPicker
    # Default upper bound on the popup's height in rows, before the
    # screen-size clamp in #build_window — keeps a picker with many
    # options from growing to fill the whole screen. Override via
    # `.centered`/`.centered_multi`'s `max_height` for a taller popup.
    DEFAULT_MAX_HEIGHT = 12

    def self.centered(screen : Screen, title : String, options : Array(FormEnumOption),
                      initial_index : Int32 = 0, max_height : Int32 = DEFAULT_MAX_HEIGHT) : {window: Window, list: OptionListView}
      source = OptionListSource.new(title, options)
      list = OptionListView.new(source)
      list.reload
      list.seek(initial_index)
      list.focus_if(true)
      {window: build_window(screen, title, options, list, max_height), list: list}
    end

    def self.centered_multi(screen : Screen, title : String, options : Array(FormEnumOption),
                            initial : Set(String), max_height : Int32 = DEFAULT_MAX_HEIGHT) : {window: Window, list: MultiOptionListView}
      source = OptionListSource.new(title, options)
      list = MultiOptionListView.new(source, initial)
      list.reload
      list.focus_if(true)
      {window: build_window(screen, title, options, list, max_height), list: list}
    end

    private def self.build_window(screen : Screen, title : String, options : Array(FormEnumOption), list : Scrollable,
                                  max_height : Int32 = DEFAULT_MAX_HEIGHT) : Window
      longest = options.max_of?(&.label.size) || 0
      w = [longest + 6, title.size + 4, 20].max
      w = [w, screen.cols - 4].min
      h = [options.size + 2, max_height].min
      h = [h, screen.rows - 4].min
      h = [h, 4].max
      x = (screen.cols - w) // 2 + 1
      y = (screen.rows - h) // 2 + 1
      Window.new(x, y, w, h, list)
    end
  end
end
