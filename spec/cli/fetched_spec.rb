require "spec_helper"

describe "bpm fetched" do
  before do
    goto_home
    set_host
    start_fake(FakeGemServer.new)
  end

  it "lists fetched packages" do
    bpm "fetch", "rake"
    wait
    bpm "fetched"

    output = stdout.read
    output.should include("rake (0.8.7)")
    output.should_not include("0.8.6")
    output.should_not include("builder")
    output.should_not include("bundler")
    output.should_not include("highline")
  end

  it "lists all installed packages from different versions" do
    bpm "fetch", "rake"
    wait
    bpm "fetch", "rake", "-v", "0.8.6"
    wait
    bpm "fetched"

    output = stdout.read
    output.should include("rake (0.8.7, 0.8.6)")
  end

  it "filters packages when given an argument" do
    bpm "fetch", "rake"
    wait
    bpm "fetch", "builder"
    wait
    bpm "fetched", "builder"

    output = stdout.read
    output.should_not include("rake")
    output.should include("builder (3.0.0)")
  end

  it "says it couldn't find any if none found" do
    bpm "fetched", "rails", :track_stderr => true

    stderr.read.strip.should == 'No packages found matching "rails".'
    exit_status.should_not be_success
  end
end
