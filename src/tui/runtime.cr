require "./core/screen"
require "./core/term"
require "./core/keys"
require "./nav/nav_stack"
require "./widget/widget"

module TUI
  # Owns the generic TUI application lifecycle: terminal setup/teardown,
  # the render/read-key/dispatch loop, SIGWINCH-driven resize, and the
  # push/pop/render mechanics of a stack of full-screen Widgets. Consumers
  # build their own widgets, wrap them in a NavStack(Widget), and hand it
  # here along with a callback for everything that isn't Ctrl-C/Ctrl-D —
  # this class owns no opinion about what any printable key (including
  # 'q') should do.
  #
  # Once a Runtime owns a NavStack, push/pop through Runtime#push/#pop
  # (not NavStack#push/#pop or #handle_esc directly) so revealed/pushed
  # widgets get resized to the current screen before their next render.
  class Runtime
    def initialize(@screen : Screen, @nav : NavStack(Widget),
                   @on_key : KeyEvent -> Nil, @io : IO = STDIN)
    end

    def run : Nil
      at_exit do
        print Term.show_cursor
        print Term.leave_mouse
        print Term.leave_alt_screen
        STDOUT.flush
        Term.exit_raw
      end

      print Term.enter_alt_screen
      print Term.hide_cursor
      print Term.enter_mouse
      STDOUT.flush
      Term.enter_raw

      Signal::WINCH.trap { resize }

      read_dispatch_loop
    end

    # The render/read-key/dispatch loop itself, without the surrounding
    # terminal setup/teardown/signal trap — split out so it's exercisable
    # against an injected IO (see @io) without touching real terminal
    # state, e.g. in specs.
    def read_dispatch_loop : Nil
      sync_size(@nav.current)
      loop do
        render
        break if @io.peek.try(&.empty?)
        ev = Keys.read(@io)
        break if ev.key == Key::CtrlC || ev.key == Key::CtrlD
        @on_key.call(ev)
      end
    end

    # Push a widget, resizing it to the current screen first.
    def push(widget : Widget) : Nil
      sync_size(widget)
      @nav.push(widget)
    end

    # Pop back to the previous widget, resyncing its size in case it went
    # stale while backgrounded.
    def pop : Nil
      @nav.pop
      sync_size(@nav.current)
    end

    # Swaps the widget at the bottom of the stack, resizing it to the
    # current screen first — for a root screen whose structure changes
    # based on runtime state.
    def replace_base(widget : Widget) : Nil
      sync_size(widget)
      @nav.replace_base(widget)
    end

    # The "delegate to child, pop only if unconsumed" idiom for Esc,
    # routed through Runtime#pop (not NavStack#pop directly) so the
    # revealed widget gets resized in case it went stale while
    # backgrounded — mirrors NavStack#handle_esc's contract exactly, but
    # callers that own a Runtime should use this one instead.
    def handle_esc(consumed : Bool, &on_pop : ->) : Nil
      return if consumed
      pop
      on_pop.call
    end

    # Forces a synchronous full render+flush outside the normal read/dispatch
    # loop. Intended for a long blocking operation (e.g. a pkg apply) that
    # emits progress via callbacks and needs the screen repainted between the
    # loop's normal render points.
    def render_now : Nil
      render
    end

    private def resize : Nil
      @screen.refresh_size
      sync_size(@nav.current)
      render
    end

    private def sync_size(widget : Widget) : Nil
      widget.width = @screen.cols
      widget.height = @screen.rows - 1
    end

    private def render : Nil
      widget = @nav.current
      widget.composite(@screen)
      @screen.status_bar(@screen.rows, widget.status_hint)
      @screen.flush
    end
  end
end
