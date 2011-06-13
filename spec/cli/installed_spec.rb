require "spec_helper"

describe "spade installed" do
  before do
    goto_home
    set_host
    # TODO: Make this LibGems specific
    env["GEM_HOME"] = spade_dir.to_s
    env["GEM_PATH"] = spade_dir.to_s
    start_fake(FakeGemServer.new)
  end

  it "lists installed spades" do
    spade "package", "install", "rake"
    wait
    spade "package", "installed"

    output = stdout.read
    output.should include("rake (0.8.7)")
    output.should_not include("0.8.6")
    output.should_not include("builder")
    output.should_not include("bundler")
    output.should_not include("highline")
  end

  it "lists all installed spades from different versions" do
    spade "package", "install", "rake"
    wait
    spade "package", "install", "rake", "-v", "0.8.6"
    wait
    spade "package", "installed"

    output = stdout.read
    output.should include("rake (0.8.7, 0.8.6)")
  end

  it "filters spades when given an argument" do
    spade "package", "install", "rake"
    wait
    spade "package", "install", "builder"
    wait
    spade "package", "installed", "builder"

    output = stdout.read
    output.should_not include("rake")
    output.should include("builder (3.0.0)")
  end

  it "says it couldn't find any if none found" do
    spade "package", "installed", "rails", :track_stderr => true

    stderr.read.strip.should == 'No packages found matching "rails".'
    exit_status.should_not be_success
  end
end
