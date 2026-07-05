require "big"

module TUI
  # Input validators for editable fields. Pure functions over strings — no
  # widget state, no I/O.
  module Validation
    # Accepted time formats — ISO 8601 variants with optional T-separator,
    # fractional seconds, and timezone offset, plus bare date.
    TIME_FORMATS = [
      "%Y-%m-%d %H:%M:%S",
      "%Y-%m-%dT%H:%M:%S",
      "%Y-%m-%d %H:%M:%S.%L",
      "%Y-%m-%dT%H:%M:%S.%L",
      "%Y-%m-%d %H:%M:%S%z",
      "%Y-%m-%dT%H:%M:%S%z",
      "%Y-%m-%d %H:%M:%S.%L%z",
      "%Y-%m-%dT%H:%M:%S.%L%z",
      "%Y-%m-%d",
    ]

    # True if the input parses successfully under any accepted format.
    def self.valid_time?(s : String) : Bool
      TIME_FORMATS.any? do |fmt|
        begin
          Time.parse(s.strip, fmt, Time::Location::UTC)
          true
        rescue
          false
        end
      end
    end

    # True if the input parses as a 64-bit signed integer.
    def self.valid_int?(s : String) : Bool
      Int64.new(s.strip)
      true
    rescue
      false
    end

    # True if the input parses as a 64-bit binary float.
    def self.valid_float?(s : String) : Bool
      Float64.new(s.strip)
      true
    rescue
      false
    end

    # True if the input parses as an arbitrary-precision decimal.
    def self.valid_decimal?(s : String) : Bool
      BigDecimal.new(s.strip)
      true
    rescue
      false
    end
  end
end
