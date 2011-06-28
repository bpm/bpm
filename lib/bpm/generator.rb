module BPM
  
  # Knows how to generate items out of the local templates directory
  class Generator
    include Thor::Actions

    attr_reader :name

    def initialize(thor, name, root)
      @thor, @name = thor, name

      self.destination_root = root
    end

    def dir_name
      File.basename destination_root
    end

  private

    def app_const
      name.gsub(/\W|-/, '_').squeeze('_').gsub(/(?:^|_)(.)/) { $1.upcase }
    end

    def current_year
      Time.now.year
    end

    def source_paths
      [self.class.source_root]
    end

    def respond_to?(*args)
      super || @thor.respond_to?(*args)
    end

    def method_missing(name, *args, &blk)
      @thor.send(name, *args, &blk)
    end
  end
end

