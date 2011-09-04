module SpecHelpers
  def env
    @env ||= {}
  end

  def load_env
    original_values = {}
    env.each do |key, val|
      original_values[key] = ENV[key]
      ENV[key] = val
    end
    @original_env = original_values.merge(@original_env || {})
  end

  def reset_env
    return unless @original_env
    @original_env.each do |key, value|
      ENV[key] = value
    end
  end
end
