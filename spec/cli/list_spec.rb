require "spec_helper"

describe "bpm list" do
  before do
    goto_home
    set_host
    start_fake(FakeGemServer.new)
  end

  describe "local" do
    before do
      FileUtils.cp_r project_fixture('hello_world'), home
      cd home('hello_world')
      bpm 'fetch' and wait # make sure rebuild step doesn't run
    end

    it "lists non-development dependencies by default" do
      bpm "list"
      output = stdout.read
      output.should include("ivory (0.0.1)")
      output.should_not include("jquery (1.4.3)")
    end

    it "lists development dependencies with --dev option" do
      bpm "list", "--dev"
      output = stdout.read
      output.should_not include("ivory (0.0.1)")
      output.should include("jquery (1.4.3)")
    end

    it "should filter output by package name" do
      bpm "list", "ivory", "spade"
      output = stdout.read
      output.should include("ivory (0.0.1)")
      output.should include("spade (0.5.0)")
      output.should_not include("optparse")
      output.should_not include("core-test")
    end

    it "should complain when called outside of a project" do
      cd home
      bpm "list", :track_stderr => true
      stderr.read.should include("inside of a BPM project")
    end

  end

  describe "remote" do

    it "lists latest packages by default" do
      bpm "list", "--remote"

      output = stdout.read
      output.should include("builder (3.0.0)")
      output.should include("rake (0.8.7)")
    end

    it "lists all packages when given the all argument" do
      bpm "list", "--remote", "-a"

      output = stdout.read
      output.should include("builder (3.0.0)")
      output.should include("rake (0.8.7, 0.8.6)")
    end

    it "filters packages when given an argument" do
      bpm "list", "builder", "--remote"

      output = stdout.read
      output.should include("builder (3.0.0)")
      output.should_not include("rake")
    end

    it "filters packages when given an argument and shows all versions" do
      bpm "list", "rake", "-a", "--remote"

      output = stdout.read
      output.should include("rake (0.8.7, 0.8.6)")
      output.should_not include("builder")
    end

    it "filters multiple packages" do
      bpm "list", "rake", "highline", "--remote"

      output = stdout.read
      output.should include("highline (1.6.1)")
      output.should include("rake (0.8.7)")
      output.should_not include("builder")
    end

    it "shows prerelease packages" do
      bpm "list", "--prerelease", "--remote"

      output = stdout.read
      output.should include("bundler (1.1.pre)")
      output.should_not include("highline")
      output.should_not include("rake")
      output.should_not include("builder")
    end

    it "says it couldn't find any if none found" do
      bpm "list", "rails", "--remote", :track_stderr => true

      stderr.read.strip.should == 'No packages found matching "rails".'
      exit_status.should_not be_success
    end

    it "says it couldn't find any if none found matching multiple packages" do
      bpm "list", "rails", "bake", "--remote", :track_stderr => true

      stderr.read.strip.should == 'No packages found matching "rails", "bake".'
      exit_status.should_not be_success
    end
  end

end
