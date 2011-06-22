require "spec_helper"

describe "bpm uninstall" do
  before do
    goto_home
    set_host
    # TODO: Fix for LibGems
    env["GEM_HOME"] = bpm_dir.to_s
    env["GEM_PATH"] = bpm_dir.to_s
    start_fake(FakeGemServer.new)
  end
  
  it "uninstalls a gem" do
    bpm "install", "rake"
    wait
    bpm "uninstall", "rake"

    stdout.read.should include("Successfully uninstalled rake-0.8.7")
    "rake-0.8.7".should_not be_fetched
    "rake-0.8.7".should_not be_unpacked
  end

  it "uninstalls multiple packages" do
    bpm "install", "rake", "highline"
    wait
    bpm "uninstall", "rake", "highline"

    output = stdout.read
    output.should include("Successfully uninstalled rake-0.8.7")
    output.should include("Successfully uninstalled highline-1.6.1")

    "rake-0.8.7".should_not be_fetched
    "rake-0.8.7".should_not be_unpacked
    "highline-1.6.1".should_not be_fetched
    "highline-1.6.1".should_not be_unpacked
  end

  it "requires at least one package to uninstall" do
    bpm "uninstall", :track_stderr => true
    stderr.read.should include("called incorrectly")
  end

  it "fails when a package is not found" do
    bpm "uninstall", "webscale", :track_stderr => true
    stderr.read.should include(%{No packages installed named "webscale"})
  end

  it "will attempt to uninstall packages even when nonexisting one is given" do
    bpm "install", "rake", "highline"
    wait
    bpm "uninstall", "rake", "webscale", :track_stderr => true

    stdout.read.should include("Successfully uninstalled rake-0.8.7")
    "rake-0.8.7".should_not be_fetched
    "rake-0.8.7".should_not be_unpacked
    stderr.read.should include(%{No packages installed named "webscale"})
  end
end
