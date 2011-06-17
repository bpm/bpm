require "spec_helper"

describe "bpm list" do
  before do
    goto_home
    set_host
    start_fake(FakeGemServer.new)
  end

  it "lists latest packages by default" do
    bpm "list"

    output = stdout.read
    output.should include("builder (3.0.0)")
    output.should include("rake (0.8.7)")
  end

  it "lists all packages when given the all argument" do
    bpm "list", "-a"

    output = stdout.read
    output.should include("builder (3.0.0)")
    output.should include("rake (0.8.7, 0.8.6)")
  end

  it "filters packages when given an argument" do
    bpm "list", "builder"

    output = stdout.read
    output.should include("builder (3.0.0)")
    output.should_not include("rake")
  end

  it "filters packages when given an argument and shows all versions" do
    bpm "list", "rake", "-a"

    output = stdout.read
    output.should include("rake (0.8.7, 0.8.6)")
    output.should_not include("builder")
  end

  it "filters multiple packages" do
    bpm "list", "rake", "highline"

    output = stdout.read
    output.should include("highline (1.6.1)")
    output.should include("rake (0.8.7)")
    output.should_not include("builder")
  end

  it "shows prerelease packages" do
    bpm "list", "--prerelease"

    output = stdout.read
    output.should include("bundler (1.1.pre)")
    output.should_not include("highline")
    output.should_not include("rake")
    output.should_not include("builder")
  end

  it "says it couldn't find any if none found" do
    bpm "list", "rails", :track_stderr => true

    stderr.read.strip.should == 'No packages found matching "rails".'
    exit_status.should_not be_success
  end

  it "says it couldn't find any if none found matching multiple packages" do
    bpm "list", "rails", "bake", :track_stderr => true

    stderr.read.strip.should == 'No packages found matching "rails", "bake".'
    exit_status.should_not be_success
  end
end
