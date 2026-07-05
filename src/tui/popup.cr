require "./widget/widget"

module TUI
  # A small, centered, non-full-screen Widget carrying a title and a
  # message, dismissed by any key. Push it via NavStack#push directly
  # (bypassing Runtime#push/#sync_size, per NavStack's own documented
  # escape hatch for modals) so it keeps whatever size/position it's
  # constructed with instead of being forced full-screen.
  class Popup < Widget
    # Applied to the box border drawn by #render.
    property border_style : Style = Style.new(fg: TUI.color(:gray))

    def self.centered(screen : Screen, title : String, message : String) : Popup
      w = [message.size + 4, title.size + 4, 30].max
      w = [w, screen.cols - 4].min
      h = 5
      x = (screen.cols - w) // 2 + 1
      y = (screen.rows - h) // 2 + 1
      new(x, y, w, h, title, message)
    end

    def initialize(x : Int32, y : Int32, width : Int32, height : Int32, @title : String, @message : String)
      super(x, y, width, height)
    end

    def render : Nil
      @buffer.box(0, 0, height, width, @title, border_style)
      @buffer.set(2, 2, Term.trunc(@message, width - 4))
    end

    def handle_key(ev : KeyEvent) : Bool
      true
    end

    def status_hint : String
      "any key: dismiss"
    end
  end
end
