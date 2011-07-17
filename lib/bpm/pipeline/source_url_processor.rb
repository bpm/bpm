require 'sprockets'

module BPM
  
  class SourceURLProcessor < Sprockets::Processor
    
    def evaluate(context, locals)
      return data if context.environment.mode != :debug
      
      root_path = file.to_s[context.environment.project.root_path.size+1..-1]
      return %(eval(#{data.to_json[0..-2]}\\n//@sourceURL=#{file}");\n)
    end
    
  end

end
