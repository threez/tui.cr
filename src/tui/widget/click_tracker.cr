module TUI
  # Tracks repeated clicks on the same logical target (e.g. a list row
  # index) to detect a double-click, independent of scrolling/rendering —
  # a double-click doesn't require its target to be scrollable.
  class ClickTracker
    # Max gap between two clicks on the same target for #register to
    # treat them as a double-click. Overridable per instance via
    # #initialize's `threshold` argument.
    DEFAULT_THRESHOLD = 400.milliseconds

    def initialize(@threshold : Time::Span = DEFAULT_THRESHOLD)
      @last_target = nil.as(Int32?)
      @last_at = nil.as(Time::Instant?)
    end

    # Register a click on `target`. Returns true if this click completes a
    # double-click (same target, within `@threshold` of the previous
    # click) — and on a true double-click, resets internal state so a
    # third rapid click starts a fresh pair rather than chaining. Returns
    # false otherwise (recording this click as the new "last click").
    def register(target : Int32) : Bool
      now = Time.instant
      if @last_target == target && (last_at = @last_at) && (now - last_at) < @threshold
        @last_target = nil
        @last_at = nil
        true
      else
        @last_target = target
        @last_at = now
        false
      end
    end
  end
end
