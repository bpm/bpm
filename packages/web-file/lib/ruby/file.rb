# ==========================================================================
# Project:   File
# Copyright: ©2010 Strobe Inc. All rights reserved.
# License:   Licened under MIT license (see LICENSE)
# ==========================================================================

require 'fileutils'

module WebFile
  class FileExports < Spade::Runtime::Exports
    
    class Blob
      
      def size
        0
      end

      attr_reader :type

      def readable
        false
      end

      def writable
        false
      end
      
      def executable
        false
      end
      
      # If true, then writing to the file will not clear the contents.
      def appends
        false
      end
      
      def initialize 
        throw self.class.context['Error'].new("Illegal constructor")
      end
      
      def slice(offset, length, contentType=nil)
        offset = size if offset > size
        length = self.size-offset if offset+length > size
        offset += @offset unless @offset.nil?
        self.dup.setup_slice(offset, length, contentType || @type)
      end

      protected 
      
      def dup
        self.class.new
      end
      
      def setup_slice(offset, length, contentType=nil)
        @offset = offset
        @length = length
        @type = contentType unless contentType.nil?
        self
      end
        
    end
    
    class File < Blob
      
      attr_reader :name, :lastModifiedDate      
      
    end
      
  end
  
  class RealFile < FileExports::File
    
    def initialize(path, ctx, perms=nil, offset=nil, length=nil, type=nil)
      @path   = path
      @ctx    = ctx
      @offset = offset.nil? ? 0 : offset
      @length = length
      @type   = type
      
      if perms.instance_of? V8::Object
        @perms = {}
        perms.each { |key, value|  @perms[key.to_sym] = value }
      else
        @perms = perms || {}
      end

      @perms_checked = false
    end

    #############################################'
    ## FILE PROPERTIES
    ##
    
    def name
      @name ||= ::File.basename(@path)
    end
    
    def lastModifiedDate
      @ctx['Date'].new(::File.mtime(@path))
    end
    
    def size 
      total_size = ::File.size(@path) - @offset
      @length.nil? || total_size<@length ? total_size : @length
    end
    
    def type
      require 'rack/mime'
      @type ||= Rack::Mime.mime_type(::File.extname(@path))
    end
    

    #############################################'
    ## PERMISSIONS
    ##

    def readable
      check_perms if !@perms_checked
      @perms[:readable] && exists
    end
    
    def writable
      check_perms if !@perms_checked
      @perms[:writable]
    end
    
    def appends
      check_perms if !@perms_checked
      @perms[:append]
    end
    
    def modifies
      check_perms if !@perms_checked
      @perms[:modify]
    end
    
    def executable
      check_perms if !@perms_checked
      @perms[:executable] 
    end
    
    def exists
      File.exists? @path
    end
    
    
    protected 
    
    def dup
      self.class.new(@path, @ctx, @perms, @offset, @length, @type)
    end
    
    # restrict file permissions to actual permissions on disk\
    def check_perms
      @perms_checked = true
      @perms = {} if @perms.nil?
      
      if File.directory?(@path)
        @perms[:readable] = @perms[:writable] = @perms[:executable] = false
      else

        path = @path
        path = File.dirname(path) while(path!='/' && !File.exists?(path))

        st = File.stat path
        @perms[:readable] &&= st.readable?
        @perms[:writable] &&= st.writable?
        @perms[:executable] &&= (path == @path) ? st.executable? : false
      end
      
      @perms[:append] &&= @perms[:writable]
      @perms[:modify]  &&= @perms[:writable] && !@perms[:append]
      
      # can only append if offset puts us at the start. i.e. slicing 
      # disables append
      if @perms[:append] && @offset>0
        @perms[:append] = false
        @perms[:modify] = true
      end
      
    end
        
    def read_sync(kind, encoding=nil)
      
      throw "File #{name} is not readable" unless readable
      
      case kind
      when :buffer
        @ctx.require 'web-typed-array'
        
        buf = WebTypedArray::ArrayBufferExports::ArrayBuffer.new(size)
        str = IO.read(@path, size, @offset||0)
        buf.instance_eval do
          @buf = str
        end
        
        buf
        
      when :text
        if encoding && encoding != 'utf8' && encoding != 'ascii'
          throw "only utf8 and ascii encoding currently supported"
        end
        IO.read(@path, size, @offset||0)
        # TODO: handle encoding

      else
        throw "do not (yet) know how to read #{kind}"
      end
    end

    def write_sync(kind, data, encoding=nil)
      
      throw "File #{name} is not writable" unless writable
      
      case kind

      when :buffer
        str = data.buf
        FileUtils.mkdir_p File.dirname(@path)
        File.open(@path, appends || modifies ? 'a' : 'w') do |fd|
          
          # write in filler if needed
          fd.seek @offset||0 unless appends

          # constrain only if this file has been sliced.
          str = str[0...size] if !@length.nil? && size < str.size
          fd.write(str)
        end        
        
      when :text
        FileUtils.mkdir_p File.dirname(@path)
        File.open(@path, appends || modifies ? 'a' : 'w') do |fd|
          fd.seek @offset unless appends
          
          # constrain only if this file has been sliced.
          data = data[0...size] if !@length.nil? && size < data.size
          fd.write(data)
        end      
        
          

      else
        throw "do not (yet) know how to write #{kind}"
      end
    end
    
    
  end
  
end

Spade.exports WebFile::FileExports
