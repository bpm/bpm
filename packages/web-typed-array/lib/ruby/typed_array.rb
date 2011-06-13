# ==========================================================================
# Project:   Web Typed Array
# Copyright: ©2010 Strobe Inc. All rights reserved.
# License:   Licened under MIT license (see LICENSE)
# ==========================================================================

module WebTypedArray
  
  class TypedArrayExports < Spade::Runtime::Exports
    
    def initialize(ctx)
      super(ctx)
      context.require 'web-typed-array/ruby/array_buffer_view'
      context.require 'web-typed-array/ruby/array_buffer'
    end
    
    # TODO: Use a string to keep the buffer packed instead of the much more
    # expensive Array
    class TypedArray
      
      include Spade::Runtime::Namespace
      
      DataView    = WebTypedArray::ArrayBufferViewExports::DataView
      ArrayBuffer = WebTypedArray::ArrayBufferExports::ArrayBuffer
      
      attr_reader :buffer
      attr_reader :byteOffset
      attr_reader :byteLength
      
      def initialize(buffer, byteOffset=nil, length=nil)
        buffer = ArrayBuffer.new(buffer) if buffer.instance_of? Fixnum
        length = length*word_size unless length.nil?

        @view = DataView.new(buffer, byteOffset, length)
        @buffer = buffer
        @byteOffset = @view.byteOffset
        @byteLength = @view.byteLength
        
      end

      def length
        @view.byteLength / word_size
      end
      
      def [](offset)
        @view.send(getter_method, offset)
      end
      
      def []=(offset, value)
        @view.send(setter_method, offset, value)
      end
      
      def set(array, offset=nil)
        throw "#set not impl yet"
      end
      
      def slice(beginOffset, endOffset)
      end
      
      protected
      
      def method_key
        self.class.superclass.to_s.sub(/^.+:(.+)Array$/, '\1')
      end
        
      def getter_method
        @getter_method ||= "get#{method_key}"
      end
      
      def setter_method
        @setter_method ||= "set#{method_key}"
      end
      
      def word_size
        @word_size ||= self.class::BYTES_PER_ELEMENT
      end
      
      
    end
    
    class Int8Array < TypedArray

      BYTES_PER_ELEMENT = 1
      
    end

    class Uint8Array < TypedArray
      
      BYTES_PER_ELEMENT = 1
      
    end

    class Int16Array < TypedArray
      
      BYTES_PER_ELEMENT = 2
      
    end

    class Uint16Array < TypedArray
      
      BYTES_PER_ELEMENT = 2
      
    end

    class Int32Array < TypedArray
      
      BYTES_PER_ELEMENT = 4
      
    end

    class Uint32Array < TypedArray
      
      BYTES_PER_ELEMENT = 4
      
    end

    class Float32Array < TypedArray
      
      BYTES_PER_ELEMENT = 4
      
    end

    class Float64Array < TypedArray
      
      BYTES_PER_ELEMENT = 8
      
    end
    
  end
  
end

Spade.exports WebTypedArray::TypedArrayExports
