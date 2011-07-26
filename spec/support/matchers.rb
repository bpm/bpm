RSpec::Matchers.define :be_fetched do
  include SpecHelpers
  match do |name|
    File.exist?(bpm_dir("cache", "#{name}.gem")) == true
  end
end

RSpec::Matchers.define :be_unpacked do
  match do |name|
    File.directory?(bpm_dir("gems", name)) == true
  end
end

RSpec::Matchers.define :exist do
  match do |name|
    File.exist?(name) == true
  end
end

RSpec::Matchers.define :have_error do |error|
  match do |package|
    package.valid? == false &&
      package.errors.include?(error) == true
  end
end
    
# Make sure matchers can get to the path helpers
class RSpec::Matchers::Matcher
  include SpecHelpers
end

