# ==========================================================================
# Project:   Web Typed Array
# Copyright: ©2010 Strobe Inc. All rights reserved.
# License:   Licened under MIT license (see LICENSE)
# ==========================================================================

module WebTypedArray
  
  class ArrayBufferExports < Spade::Runtime::Exports
    
    # TODO: Use a string to keep the buffer packed instead of the much more
    # expensive Array
    class ArrayBuffer
      
      attr_reader :buf
      
      def initialize(size)
        @buf = "\0"*size 
      end
      
      def byteLength
        @buf.size
      end
      
    end
    
  end
  
end

Spade.exports WebTypedArray::ArrayBufferExports
