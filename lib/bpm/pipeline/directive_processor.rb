require 'sprockets'

module BPM
  
  # Like the regular directive processor but knows how to resolve directives
  # as module ids, not just file paths
  class DirectiveProcessor < Sprockets::DirectiveProcessor
    
    def process_require_directive(path)
      project      = context.environment.project
      module_path  = project.path_from_module(path)
      path = context.resolve(module_path) rescue path
      context.require_asset(path)
    end
    
    def process_require_tree_directive(path = ".")
      if relative?(path)
        super path
      else
        project     = context.environment.project
        module_path = project.path_from_module path
        root = module_path.sub(/^([^\/]+)\//) do |s|
          project.path_from_package s
        end
                
        context.depend_on(root)

        Dir["#{root}/**/*"].sort.each do |filename|
          if filename == self.file
            next
          elsif File.directory?(filename)
            context.depend_on(filename)
          elsif context.asset_requirable?(filename)
            context.require_asset(filename)
          end
        end
      end
    end
    
  private
    def relative?(path)
      path =~ /^\.($|\.?\/)/
    end
    
  end
  
end


# Fix bad regexp
class Sprockets::DirectiveProcessor
  remove_const :DIRECTIVE_PATTERN
  DIRECTIVE_PATTERN = /
    ^ [^\w=]* = \s* (\w+.*?) (\*\/)? $
  /x
end
