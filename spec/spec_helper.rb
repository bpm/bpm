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
end

RSpec.configure do |config|
  working_dir = Dir.pwd

  config.include SpecHelpers

  config.around do |blk|
    reset!

    blk.call

    kill!
    stop_fake
    reset_host
    Dir.chdir working_dir if Dir.pwd != working_dir
  end
end

