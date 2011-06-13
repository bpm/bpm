# ==========================================================================
# Project:   File
# Copyright: ©2010 Strobe Inc. All rights reserved.
# License:   Licened under MIT license (see LICENSE)
# ==========================================================================

module WebFile
  class FileWriterExports < Spade::Runtime::Exports

    def initialize(ctx)
      super(ctx)
      context.require('web-file/ruby/file')
    end

    class FileWriter
      
      attr_reader :readyState, :result
      
      attr_accessor :onloadstart, :onprogress, :onload, :onerror, :onloadend
      
      def writeArrayBuffer(blob, buffer)
        throw "FileReader.writeArrayBuffer() not yet implemented"
      end

      def writeBinaryString(blob, string)
        throw "FileReader.writeBinaryString() not yet implemented"
      end

      def writeText(blob, string, encoding=nil)
        throw "FileReader.writeText() not yet implemented"
      end

      def writeDataURL(blob, url)
        throw "FileReader.writeDataURL() not yet implemented"
      end

      def abort(*args)
        throw "FileReader.abort not yet implemented"
      end
    end

    class FileWriterSync

      # This will reset the contents of the file referenced by the blob.
      def truncate(blob)
        blob.send(:truncate)
      end
      
      def writeArrayBuffer(blob, buffer)
        throw "Blob is not a real file" unless blob.instance_of? RealFile
        blob.send(:write_sync, :buffer, buffer)
        nil
      end

      def writeBinaryString(blob, string)
        throw "Blob is not a real file" unless blob.instance_of? RealFile
        blob.send(:write_sync, :binary, string)
        nil
      end

      def writeText(blob, string, encoding=nil)
        throw "Blob is not a real file" unless blob.instance_of? RealFile
        blob.send(:write_sync, :text, string, encoding)
        nil
      end

      def writeDataURL(blob, url)
        throw "Blob is not a real file" unless blob.instance_of? RealFile
        blob.send(:write_sync, :data_url, url)
        nil
      end

    end
      
  end
end

Spade.exports WebFile::FileWriterExports
