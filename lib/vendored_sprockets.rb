if defined?(Sprockets)
  warn "Sprockets has already been required. " +
    "This may cause BPM to malfunction in unexpected ways."
end
$:.unshift File.expand_path('../../vendor/sprockets/lib', __FILE__)
require 'sprockets'

