# ==========================================================================
# Project:   Web Typed Array
# Copyright: ©2010 Strobe Inc. All rights reserved.
# License:   Licened under MIT license (see LICENSE)
# ==========================================================================

module WebTypedArray
  
  class ArrayBufferViewExports < Spade::Runtime::Exports
    
    class ArrayBufferView

      attr_reader :buffer
      
      def byteOffset
        @byte_offset
      end
      
      def byteLength
        @byte_length
      end
      
      
    end

    class DataView < ArrayBufferView
      
      def initialize(buffer, byte_offset=nil, byte_length=nil)
        @buffer = buffer
        @byte_offset = byte_offset || 0
        if byte_length.nil? || (byte_length+@byte_offset > buffer.byteLength)
          @byte_length = buffer.byteLength - @byte_offset
        else
          @byte_length = byte_length
        end
      end

      ############################################
      ## Getters
      ##
      
      def getInt8(byteOffset)
        unpack byteOffset, 'c'
      end

      def getUint8(byteOffset)
        unpack byteOffset, 'C'
      end
      
      def getInt16(byteOffset)
        unpack byteOffset, 's'
      end

      def getUint16(byteOffset)
        unpack byteOffset, 'S'
      end
      
      def getInt32(byteOffset)
        unpack byteOffset, 'l'
      end

      def getUint32(byteOffset)
        unpack byteOffset, 'L'
      end

      def getFloat32(byteOffset)
        unpack byteOffset, 'g'
      end

      def getFloat64(byteOffset)
        unpack byteOffset, 'G'
      end

      ############################################
      ## Setters
      ##
      
      def setInt8(byteOffset, value)
        pack byteOffset, value, 'c'
      end

      def setUint8(byteOffset, value)
        pack byteOffset, value, 'C'
      end
      
      def setInt16(byteOffset, value)
        pack byteOffset, value, 's'
      end

      def setUint16(byteOffset, value)
        pack byteOffset, value, 'S'
      end
      
      def setInt32(byteOffset, value)
        pack byteOffset, value, 'l'
      end

      def setUint32(byteOffset, value)
        pack byteOffset, value, 'L'
      end

      def setFloat32(byteOffset, value)
        pack byteOffset, value, 'g'
      end

      def setFloat64(byteOffset, value)
        pack byteOffset, value, 'G'
      end
      
      
      private
      
      def pack(offset, value, code)
        value = [value].pack(code)
        @buffer.buf[offset, value.size] = value
        nil
      end
      
      def unpack(offset, code)
        @buffer.buf.unpack("@#{offset}#{code}")[0]
      end
      
    end
    
    
  end
  
end

Spade.exports = WebTypedArray::ArrayBufferViewExports
