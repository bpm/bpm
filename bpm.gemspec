# -*- encoding: utf-8 -*-
lib = File.expand_path('../lib/', __FILE__)
$:.unshift lib unless $:.include?(lib)

require 'bpm/version'

Gem::Specification.new do |s|
  s.name        = "bpm"
  s.version     = BPM::VERSION
  s.platform    = Gem::Platform::RUBY
  s.authors     = ["Charles Jolley", "Peter Wagenet"]
  s.email       = ["charles@sproutcore.com", "peterw@strobecorp.com"]
  s.homepage    = "http://github.com/getbpm/bpm"
  s.summary = s.description = "Browser Package Manager"

  mswin = RbConfig::CONFIG["host_os"] =~ %r!(msdos|mswin|djgpp|mingw)!
  mri = !mswin && (!defined?(RUBY_ENGINE) || RUBY_ENGINE == "ruby")

  s.add_dependency "libgems",      "~> 0.1.3"
  s.add_dependency "gemcutter",    "~> 0.6.1"
  s.add_dependency "highline",     "~> 1.6.1"
  s.add_dependency "json_pure",    "~> 1.4.6"
  s.add_dependency "thor",         "~> 0.14.3"
  s.add_dependency "execjs",       "~> 1.2.4"
  s.add_dependency "sprockets",    "~> 2.0.0"
  s.add_dependency "eventmachine", "~> 1.0.0.beta.4" # There are issues with 0.12.10 and thin
  s.add_dependency "thin",         "~> 1.2"

  s.add_development_dependency "rspec"
  s.add_development_dependency "rack", "~> 1.3.2"

  paths = `git submodule`.split("\n").map do |line|
    path = line.gsub(/^.\w+\s+(\S+).*/,'\1')
    `cd #{path}; git ls-files`.split("\n").map { |p| File.join(path, p) }
  end
  paths << `git ls-files`.split("\n")
  s.files      = paths.flatten
  s.test_files = `git ls-files -- {test,spec,features}/*`.split("\n")

  s.executables        = ['bpm']
  s.require_paths      = ["lib"]
end

