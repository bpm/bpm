# ==========================================================================
# Project:   File
# Copyright: ©2010 Strobe Inc. All rights reserved.
# License:   Licened under MIT license (see LICENSE)
# ==========================================================================

module WebFile
  class FileReaderExports < Spade::Runtime::Exports

    def initialize(ctx)
      super(ctx)
      context.require('web-file/ruby/file')
    end

    class FileReader
      
      attr_reader :readyState, :result
      
      attr_accessor :onloadstart, :onprogress, :onload, :onerror, :onloadend
      
      def readAsArrayBuffer(blob)
        throw "FileReader.readAsArrayBuffer() not yet implemented"
      end

      def readAsBinaryString(blob)
        throw "FileReader.readAsBinaryString() not yet implemented"
      end

      def readAsText(blob, encoding=nil)
        throw "FileReader.readAsText() not yet implemented"
      end

      def readAsDataURL(blob)
        throw "FileReader.readAsDataURL() not yet implemented"
      end

      def abort(*args)
        throw "FileReader.abort not yet implemented"
      end
    end

    class FileReaderSync
      
      def readAsArrayBuffer(blob)
        throw "Blob is not a real file" unless blob.instance_of? RealFile
        blob.send(:read_sync, :buffer)
      end

      def readAsBinaryString(blob)
        throw "Blob is not a real file" unless blob.instance_of? RealFile
        blob.send(:read_sync, :binary)
      end

      def readAsText(blob, encoding=nil)
        throw "Blob is not a real file" unless blob.instance_of? RealFile
        blob.send(:read_sync, :text, encoding)
      end

      def readAsDataURL(blob)
        throw "Blob is not a real file" unless blob.instance_of? RealFile
        blob.send(:read_sync, :data_url)
      end

    end
      
  end
end

Spade.exports WebFile::FileReaderExports
