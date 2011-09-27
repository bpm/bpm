begin
  require 'packager/rake_task'

  Packager::RakeTask.new(:pkg) do |t|
    t.package_name = "BPM"
    t.version = BPM::VERSION
    t.domain = "strobecorp.com"
    t.bin_files = ["bpm"]
    t.resource_files = ["README.md", "support", "templates"]
  end
rescue LoadError
end
