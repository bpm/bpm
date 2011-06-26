# A sample Gemfile
source "http://rubygems.org"

if ENV["SPADE_PATH"]
  gem 'spade', :path => ENV["SPADE_PATH"]
else
  gem 'spade', :git => "git://github.com/sproutcore/spade-ruby"
end

if ENV["SPOCKETS_PATH"]
  gem 'sprockets', :path => ENV["SPROCKETS_PATH"]
else
  gem 'sprockets', :git => "git://github.com/sstephenson/sprockets"
end

gemspec
