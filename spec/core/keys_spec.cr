require "../spec_helper"

# Keys.read only applies its escape-sequence follow-up timeout to an
# IO::FileDescriptor (see Keys.read_byte_timeout) — a plain IO::Memory
# always looks like "no more bytes yet" and every escape sequence would
# bail out early as a bare Esc. Route the bytes through a real pipe so the
# reading side is a genuine file descriptor, matching how STDIN is read
# in production.
private def read_from(bytes : Bytes) : TUI::KeyEvent
  reader, writer = IO.pipe
  writer.write(bytes)
  writer.close
  TUI::Keys.read(reader)
ensure
  reader.try &.close
end

describe TUI::Keys do
  describe ".read" do
    it "parses a plain character" do
      read_from("x".to_slice).key.should eq(TUI::Key::Char)
    end

    it "parses an arrow key" do
      read_from("\e[A".to_slice).key.should eq(TUI::Key::Up)
    end

    it "parses SGR mouse wheel-up (button code 64)" do
      read_from("\e[<64;12;5M".to_slice).key.should eq(TUI::Key::MouseWheelUp)
    end

    it "parses SGR mouse wheel-down (button code 65)" do
      read_from("\e[<65;12;5M".to_slice).key.should eq(TUI::Key::MouseWheelDown)
    end

    it "parses SGR mouse release events without hanging" do
      read_from("\e[<65;1;1m".to_slice).key.should eq(TUI::Key::MouseWheelDown)
    end

    it "parses SGR mouse left-click press with position" do
      ev = read_from("\e[<0;12;5M".to_slice)
      ev.key.should eq(TUI::Key::MouseClick)
      ev.col.should eq(12)
      ev.row.should eq(5)
    end

    it "ignores SGR mouse left-click release" do
      read_from("\e[<0;12;5m".to_slice).key.should eq(TUI::Key::Unknown)
    end

    it "ignores non-left SGR mouse buttons" do
      read_from("\e[<1;1;1M".to_slice).key.should eq(TUI::Key::Unknown)
    end
  end
end
