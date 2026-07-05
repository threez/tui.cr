module TUI
  # A navigation stack of app-defined entries (typically a union of `record`
  # types, one per screen/state). Captures the push/pop/current idiom and
  # the "delegate a key to the active widget, only pop if it wasn't
  # consumed" bubbling rule that recurs anywhere a stack of views is
  # keyboard-navigable.
  #
  # Deliberately minimal: `push`/`pop` are plain stack primitives an app can
  # also call directly when it needs to bypass the normal flow (e.g. to push
  # a modal without triggering a rebuild-on-change side effect elsewhere, in
  # order to preserve in-progress state on the widget being covered).
  class NavStack(T)
    def initialize(root : T)
      @stack = [root] of T
    end

    def current : T
      @stack.last
    end

    def size : Int32
      @stack.size
    end

    def push(entry : T) : Nil
      @stack << entry
    end

    def pop : Nil
      @stack.pop if @stack.size > 1
    end

    # Replaces the entry at the bottom of the stack (index 0) in place,
    # leaving anything pushed on top untouched — for a root screen whose
    # structure changes based on runtime state (e.g. a side panel that
    # appears/disappears).
    def replace_base(entry : T) : Nil
      @stack[0] = entry
    end

    # The "delegate to child, pop only if unconsumed" idiom for Esc:
    # `nav.handle_esc(child.handle_key(ev)) { pkg_list.focused = true }`
    def handle_esc(consumed : Bool, &on_pop : ->) : Nil
      return if consumed
      pop
      on_pop.call
    end
  end
end
