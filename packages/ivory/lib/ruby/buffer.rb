# ==========================================================================
# Project:   Ivory
# Copyright: ©2010 Strobe Inc. All rights reserved.
# License:   Licened under MIT license (see LICENSE)
# ==========================================================================

require 'v8'

module Ivory
  class BufferModule < Spade::Runtime::Exports
    
    class SlowBuffer
      attr_reader :data
      protected :data

      def initialize(opt, *args)
        case opt
        when Numeric
          @data = Array.new(opt.to_i, 0)
        when V8::Array
          @data = opt.to_a
        when String
          encoding = *args
          @data = case encoding
          when 'ascii'                        then opt.unpack('U*')
          when 'utf8','utf-8','binary',nil    then opt.unpack('C*')
          when 'base64'
            (opt + "=" * (4 - opt.length % 4)).unpack('m').first.unpack('C*')
          else
            raise "Unknown encoding"
          end
        when self.class
          start, stop = *args
          @data = opt.send(:data)[start..stop-1]
        else
          raise "Bad argument"
        end
      end
      
      def length
        @data.length
      end

      def [](index)
        index.kind_of?(Numeric) ? @data[index] : yield
      end

      def []=(index, value)
        index.kind_of?(Numeric) ? @data[index] = value : yield
      end

      def slice(start, stop)
        SlowBuffer.new(self, start, stop)
      end

      def unpack(format, index)
        raise ArgumentError, "Argument must be a string" unless format.kind_of?(String)
        @data[index..-1].pack('C*').unpack(format).tap do |array|
          raise ArgumentError, "Out of bounds" if array.last.nil?
        end
      end

      def utf8Slice(start, stop)
        @data[start..stop-1].pack('C*')
      end

      def asciiSlice(start, stop)
        raise ArgumentError, "Bad argument." unless start.kind_of?(Numeric) && stop.kind_of?(Numeric)
        raise ArgumentError, "Bad argument." if start < 0 || stop < 0
        raise ArgumentError, "Must have start <= end" unless start <= stop
        raise ArgumentError, "end cannot be longer than parent" if stop > @data.length

        @data[start..stop-1].pack('C*').tap do |slice|
          # puts "Buffer(#{self.length}).asciiSlice(#{start}, #{stop}) -> #{slice}"
        end
      end

      def binarySlice(start, stop)
        @data[start..stop-1]
      end

      def base64Slice(start, stop)
        [@data[start..stop-1].pack('C*')].pack('m').gsub(/\n/,'')
      end

      def utf8Write(string, offset)
        written = 0
        string.scan(/./mu) do |codepoint|
          bytes = codepoint.unpack('C*')
          if bytes.length <= self.length - offset - written
            @data[offset + written, bytes.length] = bytes
            written += bytes.length
          end
        end
        return written
      end

      def asciiWrite(string, offset)
        raise "Argument must be a string" unless string.kind_of?(String)
        raise "Offset is out of bounds" if string.length > 0 && offset >= self.length
        to_write = [string.length, self.length - offset].min
        @data[offset, to_write] = string.unpack('C*')
        to_write
      end

      def binaryWrite(string, offset)
        raise "Argument must be a string" unless string.kind_of?(String)
        0
      end

      def base64Write(string, offset)
        return 0 if offset == 0 && self.length == 0
        raise "Offset is out of bounds" if offset >= self.length
        bytes = string.unpack('m').first.unpack('C*')
        raise "Buffer too small" if bytes.length > (self.length - offset)
        @data[offset, bytes.length] = bytes
        bytes.length
      end

      def copy(target, position, start, finish = self.length)
        raise "First arg should be a Buffer" unless target.kind_of?(self.class)
        raise "sourceEnd < sourceStart" if finish < start
        return 0 if start == finish

        raise "targetStart out of bounds" if position < 0 || position >= target.length
        raise "sourceStart out of bounds" if start < 0 || start >= self.length
        raise "sourceEnd out of bounds" if finish < 0 || finish > self.length

        to_copy = [finish - start, target.length - position].min.tap do |bytes|
          for i in 0..bytes - 1
            target[i] = self[i]
          end
        end
      end
      
      def to_s
        @data.pack("C*")
      end
      
    end
  end
end

Spade.exports = Ivory::BufferModule

