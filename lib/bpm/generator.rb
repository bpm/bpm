require 'thor'
require 'bpm'

module BPM

  def self.generators
    @generators ||= {}
  end

  def self.register_generator(pkg, type, generator)
    generators[pkg] ||= {}
    generators[pkg][type] = generator
  end

  def self.generator_for(pkg_or_type, type=nil, default=true)
    if type
      pkg = pkg_or_type
    else
      pkg = :default
      type = pkg_or_type
    end

    generator = generators[pkg] && generators[pkg][type]
    generator ||= generators[:default] && generators[:default][type] if default
    generator
  end

  # Knows how to generate items out of the local templates directory
  class Generator
    include Thor::Actions

    attr_reader :name

    def initialize(thor, name, root, template_path=nil)
      @thor, @name, @template_path = thor, name, template_path

      self.destination_root = root
    end

    def dir_name
      File.basename destination_root
    end

    def source_paths
      [@template_path, self.class.source_root].compact
    end

  private

    def app_const
      name.gsub(/\W|-/, '_').squeeze('_').gsub(/(?:^|_)(.)/) { $1.upcase }
    end

    def current_year
      Time.now.year
    end

    def respond_to?(*args)
      super || @thor.respond_to?(*args)
    end

    def method_missing(name, *args, &blk)
      @thor.send(name, *args, &blk)
    end
  end
end

require 'bpm/init_generator'
require 'bpm/project_generator'
