# ==========================================================================
# Project:   File
# Copyright: ©2010 Strobe Inc. All rights reserved.
# License:   Licened under MIT license (see LICENSE)
# ==========================================================================

require 'fileutils'

module WebFile
  class FileSystemExports < Spade::Runtime::Exports

    def initialize(ctx)
      super(ctx)
      self.context.require 'web-file/ruby/file'
    end
    
    SEPARATOR = File::SEPARATOR
    
    def cwd 
      Dir.pwd
    end
    
    def open(path, perms=nil, offset=nil, length=nil)
      RealFile.new path, self.context, perms, offset, length
    end
    
    def exists(path)
      File.exists? path
    end
    
    def stat(path)
      File.stat path
    end

    def glob(path)
      Dir.glob path
    end
    
    #############################################'
    ## FS ACTIONS
    ##
    
    DEF_OPTS = {} # { :verbose => true, :noop => true }
    
    def mkdir(path, mode=nil)
      opts = DEF_OPTS.dup
      opts[:mode] = mode unless mode.nil?
      FileUtils.mkdir clean_args(path), opts
    end
    
    def mkdir_p(path, mode=nil)
      opts = DEF_OPTS.dup
      opts[:mode] = mode unless mode.nil?
      FileUtils.mkdir_p clean_args(path), opts
    end
    
    def mv(src, dst)
      FileUtils.mv clean_args(src), clean_args(dst), DEF_OPTS
    end
    
    def cp(src, dst)
      FileUtils.cp clean_args(src), clean_args(dst), DEF_OPTS
    end

    def cp_r(src, dst)
      FileUtils.cp_r clean_args(src), clean_args(dst), DEF_OPTS
    end

    def rm(src)
      FileUtils.rm clean_args(src), DEF_OPTS
    end

    def rm_r(src)
      FileUtils.rm_r clean_args(src), DEF_OPTS
    end

    def rm_rf(src)
      FileUtils.rm_rf clean_args(src), DEF_OPTS
    end
    
    def ln(src, dst)
      FileUtils.ln clean_args(src), clean_args(dst), DEF_OPTS
    end
    
    def ln_s(src, dst)
      FileUtils.ln_s clean_args(src), clean_args(dst), DEF_OPTS
    end    

    #############################################'
    ## PATH
    ##
    
    def expand_path(path, root=nil)
      File.expand_path path, root
    end
    
    def join_path(*args)
      File.join(*clean_args(args))
    end
    
    def split_path(path)
      File.split(path)
    end
    
    def dirname(path)
      File.dirname(path)
    end
    
    def basename(path, root=nil)
      File.basename(path, root)
    end
    
    def extname(path)
      File.extname(path)
    end
    
    protected
    
    def clean_args(args)
      case args
      when V8::Array
        args.to_a.map { |a| clean_args(a) }

      when Array
        args.to_a.map { |a| clean_args(a) }
      else
        args
      end
    end
          
  end
end

Spade.exports WebFile::FileSystemExports
