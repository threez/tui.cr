module TUI
  enum Key
    Up
    Down
    Left
    Right
    Enter
    Esc
    Tab
    ShiftTab
    Backspace
    Delete
    PageUp
    PageDown
    Home
    End
    CtrlC
    CtrlD
    CtrlX
    Char
    MouseWheelUp
    MouseWheelDown
    MouseClick
    Unknown
  end

  # A single parsed input event. `char` is only meaningful when
  # `key == Key::Char` (the literal typed character); `row`/`col` are only
  # set for `Key::MouseClick` (1-based terminal coordinates — see
  # Keys.parse_sgr_mouse) and nil for every other kind, including the
  # wheel events, which carry no position.
  record KeyEvent, key : Key, char : Char = '\0', row : Int32? = nil, col : Int32? = nil

  module Keys
    # How long .read_byte_timeout waits for a follow-up byte after a bare
    # `\e`, to tell a real Esc keypress apart from the start of a longer
    # escape sequence (arrow keys, mouse reports, etc).
    ESC_TIMEOUT = 50.milliseconds

    def self.read(io : IO) : KeyEvent
      byte = io.read_byte
      return KeyEvent.new(Key::Unknown) if byte.nil?

      ch = byte.chr

      case ch
      when '\r', '\n'
        KeyEvent.new(Key::Enter)
      when '\t'
        KeyEvent.new(Key::Tab)
      when '', '\b'
        KeyEvent.new(Key::Backspace)
      when ''
        KeyEvent.new(Key::CtrlC)
      when ''
        KeyEvent.new(Key::CtrlD)
      when ''
        KeyEvent.new(Key::CtrlX)
      when '\e'
        parse_escape(io)
      else
        if byte >= 32
          KeyEvent.new(Key::Char, ch)
        else
          KeyEvent.new(Key::Unknown)
        end
      end
    end

    private def self.read_byte_timeout(io : IO) : UInt8?
      if fd = io.as?(IO::FileDescriptor)
        old = fd.read_timeout
        fd.read_timeout = ESC_TIMEOUT
        begin
          fd.read_byte
        rescue IO::TimeoutError
          nil
        ensure
          fd.read_timeout = old
        end
      else
        nil
      end
    end

    private def self.parse_escape(io : IO) : KeyEvent
      next_byte = read_byte_timeout(io)
      return KeyEvent.new(Key::Esc) if next_byte.nil?

      case next_byte.chr
      when '['
        parse_csi(io)
      when 'Z'
        KeyEvent.new(Key::ShiftTab)
      else
        KeyEvent.new(Key::Esc)
      end
    end

    private def self.parse_csi(io : IO) : KeyEvent
      first = read_byte_timeout(io)
      return KeyEvent.new(Key::Unknown) if first.nil?
      return parse_sgr_mouse(io) if first.chr == '<'

      csi_key(read_csi_seq(io, first.chr))
    end

    private def self.read_csi_seq(io : IO, first : Char) : String
      seq = String::Builder.new
      seq << first
      7.times do
        b = read_byte_timeout(io)
        break if b.nil?
        c = b.chr
        seq << c
        break if c >= '@' && c <= '~'
      end
      seq.to_s
    end

    private def self.csi_key(seq : String) : KeyEvent
      case seq
      when "A"  then KeyEvent.new(Key::Up)
      when "B"  then KeyEvent.new(Key::Down)
      when "C"  then KeyEvent.new(Key::Right)
      when "D"  then KeyEvent.new(Key::Left)
      when "H"  then KeyEvent.new(Key::Home)
      when "F"  then KeyEvent.new(Key::End)
      when "5~" then KeyEvent.new(Key::PageUp)
      when "6~" then KeyEvent.new(Key::PageDown)
      when "3~" then KeyEvent.new(Key::Delete)
      else           KeyEvent.new(Key::Unknown)
      end
    end

    # SGR extended mouse reporting (`\e[<Cb;Cx;CyM` / `...m`, enabled via
    # Term.enter_mouse). Cb encodes the button/event: 64 is wheel-up, 65 is
    # wheel-down, 0 is a plain left-click. Cx/Cy (1-based column/row) are
    # parsed for left-clicks so callers can hit-test which row was clicked;
    # they're irrelevant for wheel events and left unset there.
    private def self.parse_sgr_mouse(io : IO) : KeyEvent
      params = String::Builder.new
      terminator = nil
      loop do
        b = read_byte_timeout(io)
        break if b.nil?
        c = b.chr
        if c == 'M' || c == 'm'
          terminator = c
          break
        end
        params << c
      end

      parts = params.to_s.split(';')
      cb = parts[0]?.try(&.to_i?)
      cx = parts[1]?.try(&.to_i?)
      cy = parts[2]?.try(&.to_i?)

      case cb
      when 64 then KeyEvent.new(Key::MouseWheelUp)
      when 65 then KeyEvent.new(Key::MouseWheelDown)
      when 0
        # Only the press (M) selects/activates; ignore the release (m),
        # same as any other button/motion event is ignored below.
        if terminator == 'M' && cx && cy
          KeyEvent.new(Key::MouseClick, row: cy, col: cx)
        else
          KeyEvent.new(Key::Unknown)
        end
      else
        KeyEvent.new(Key::Unknown)
      end
    end
  end
end
