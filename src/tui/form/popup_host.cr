require "../core/screen"
require "../nav/nav_stack"
require "../widget/widget"

module TUI
  module Form
    # Narrows whatever an app hosts its widget navigation with (a
    # NavStack(Widget) plus the Screen it was sized against) down to the
    # three operations Form::Host actually needs to open/close a dropdown
    # popup, so Host doesn't need the app's full navigation type threaded
    # through it.
    record PopupHost, screen : Screen, push : Widget -> Nil, pop : -> Nil
  end
end
