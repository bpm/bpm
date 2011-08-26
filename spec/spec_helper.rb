Bundler.require :default, :development

require 'support/env'
require 'support/cli'
require 'support/fake'
require 'support/fake_gem_server'
require 'support/fake_gemcutter'
require 'support/matchers'
require 'support/path'
require 'support/project'

module SpecHelpers
  def set_host(host='http://localhost:9292')
    @original_host ||= LibGems.host
    @original_sources ||= LibGems.sources
    LibGems.host = host
    LibGems.sources = [LibGems.host]
  end

  def reset_host
    LibGems.host = @original_host if @original_host
    LibGems.sources = @original_sources if @original_sources
  end

  # Use to avoid throwing errors just because an extra newline shows up
  # somewhere
  def normalize_whitespace(string)
    string.gsub(/ +/, ' ').gsub(/\n+/,"\n")
  end
  
  def compare_file_contents(actual_path, expected_path)
    actual_contents   = normalize_whitespace File.read(actual_path)
    expected_contents = normalize_whitespace File.read(expected_path)
    actual_contents.should == expected_contents
  end
    
  # compares the contents of two directories to ensure they are the same.
  # ignores any whitespaces on files.
  def compare_contents(actual_root, expected_root)
    actual_root    = actual_root.to_s
    expected_root  = expected_root.to_s # incase Pathname is passed

    if File.directory? expected_root
      # first make sure the same files are in each.
      expected_files = Dir.glob(File.join(expected_root, '**', '*')).sort
      actual_files   = Dir.glob(File.join(actual_root, '**', '*')).sort
    
      actual_files.map! { |path| expected_root + path[actual_root.size..-1] }
      actual_files.should == expected_files

      expected_files.each do |expected_path|
        display_path = expected_path[expected_root.size..-1]
        actual_path = @project_path + display_path
        if File.directory? expected_path
          File.directory?(actual_path).should be_true
        else
          compare_file_contents actual_path, expected_path
        end
      end
    else
      compare_file_contents actual_path, expected_path
    end
  end

end

RSpec.configure do |config|
  working_dir = Dir.pwd

  config.include SpecHelpers

  config.before do
    reset!
  end

  config.after do
    kill!
    stop_fake
    reset_host
    reset_env
    Dir.chdir working_dir if Dir.pwd != working_dir
  end
end

