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
    Unknown
  end

  record KeyEvent, key : Key, char : Char = '\0'

  module Keys
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
      when '', '\b'
        KeyEvent.new(Key::Backspace)
      when ''
        KeyEvent.new(Key::CtrlC)
      when ''
        KeyEvent.new(Key::CtrlD)
      when ''
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
      seq = String::Builder.new
      8.times do
        b = read_byte_timeout(io)
        break if b.nil?
        c = b.chr
        seq << c
        break if c >= '@' && c <= '~'
      end

      case seq.to_s
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
  end
end
