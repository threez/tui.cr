require "./scroller"

module TUI
  # A narrow handle onto a Window's Scroller, handed to Scrollable content
  # so it can drive scrolling (reveal-on-select, page up/down, wheel ticks)
  # without owning the Scroller itself or knowing its own viewport size
  # beyond what's captured here at construction time.
  struct ScrollControl
    def initialize(@scroller : Scroller, @visible : Int32)
    end

    def offset : Int32
      @scroller.offset
    end

    # The viewport size this control was constructed with — content uses
    # this as the page-size for PageUp/PageDown (matching what Window
    # itself measured as the visible content area for this frame).
    def visible : Int32
      @visible
    end

    def reveal(index : Int32) : Nil
      @scroller.reveal(index, @visible)
    end

    def up(by : Int32 = 1) : Nil
      @scroller.up(by)
    end

    def down(by : Int32 = 1, total : Int32 = Int32::MAX) : Nil
      @scroller.down(by, total: total, visible: @visible)
    end

    def wheel_up(by : Int32 = Scroller::WHEEL_STEP) : Nil
      @scroller.wheel_up(by)
    end

    def wheel_down(by : Int32 = Scroller::WHEEL_STEP, total : Int32 = Int32::MAX) : Nil
      @scroller.wheel_down(by, total: total, visible: @visible)
    end

    def reset : Nil
      @scroller.reset
    end
  end
end
