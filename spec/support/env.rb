module SpecHelpers
  def env
    @env ||= {}
  end

  def with_env
    original_values = {}
    env.each do |key, val|
      original_values[key] = ENV[key]
      ENV[key] = val
    end
    yield
  ensure
    original_values.each do |key, value|
      ENV[key] = value
    end
  end
end
