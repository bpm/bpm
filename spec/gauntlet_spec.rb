require "spec_helper"

describe "bpm build the gauntlet" do
  it "should work" do
    pending "Possibly add some fixtures to test"
  end

=begin
  before do
    cd(home)
    env["HOME"] = home.to_s
    write_creds("user@example.com", "deadbeef")
  end

  {
    "ivory"                => "0.0.1",
    "jquery"               => "1.4.3",
    "optparse"             => "1.0.1",
    "web-file"             => "0.0.1",
    "web-typed-array"      => "0.0.1",
  }.each do |package, version|
    it "builds a package from #{package}" do
      FileUtils.cp_r root.join("packages/#{package}"), package
      cd package
      bpm "build"

      exit_status.should be_success
      stdout.read.should include("Successfully built package: #{package}-#{version}.bpkg")
      File.exist?(tmp.join(package, "#{package}-#{version}.bpkg"))
    end
  end
=end
end
