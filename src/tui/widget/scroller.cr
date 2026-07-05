module TUI
  class Scroller
    # Rows moved per mouse wheel tick — one shared default so widgets
    # don't each redeclare an identical constant.
    WHEEL_STEP = 3

    # First visible content row, 0-based. Kept in range by #clamp — call
    # that every render rather than trusting this to stay valid on its own
    # after content or viewport size changes.
    getter offset : Int32

    def initialize(@offset : Int32 = 0)
    end

    # Recompute a valid offset against current content/viewport sizes.
    # Call every render — self-heals when content shrinks (filter, toggle)
    # or the widget resizes, without every mutation site needing to remember
    # to reset/clamp separately.
    def clamp(total : Int32, visible : Int32) : Nil
      max_offset = [total - visible, 0].max
      @offset = @offset.clamp(0, max_offset)
    end

    def reset : Nil
      @offset = 0
    end

    def up(by : Int32 = 1) : Nil
      @offset = [@offset - by, 0].max
    end

    def down(by : Int32 = 1, total : Int32 = Int32::MAX, visible : Int32 = 0) : Nil
      max_offset = [total - visible, 0].max
      @offset = [@offset + by, max_offset].min
    end

    # Ensure `index` is within the visible window — scrolls minimally.
    def reveal(index : Int32, visible : Int32) : Nil
      @offset = index if index < @offset
      @offset = index - visible + 1 if index >= @offset + visible
    end

    # 0.0..1.0 position of the viewport within the content, or nil if the
    # content fits entirely (no scrollbar needed).
    def fraction(total : Int32, visible : Int32) : Float64?
      return nil if total <= visible
      max_offset = total - visible
      max_offset > 0 ? @offset / max_offset.to_f : 0.0
    end

    # Wheel-tick convenience over #up/#down — same semantics, just names
    # the common case and supplies the shared step default. #up/#down
    # remain the primitives (used by PageUp/PageDown/arrow keys).
    def wheel_up(by : Int32 = WHEEL_STEP) : Nil
      up(by)
    end

    def wheel_down(by : Int32 = WHEEL_STEP, total : Int32 = Int32::MAX, visible : Int32 = 0) : Nil
      down(by, total: total, visible: visible)
    end
  end
end
