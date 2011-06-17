require "spec_helper"

describe "bpm install" do
  before do
    goto_home
    set_host
    start_fake(FakeGemServer.new)
  end

  it "installs a valid gem" do
    bpm "install", "rake"

    stdout.read.should include("Successfully installed rake-0.8.7")

    "rake-0.8.7".should be_fetched
    "rake-0.8.7".should be_unpacked
  end

  it "installs a multiple gems" do
    bpm "install", "rake", "builder"

    output = stdout.read

    %w[builder-3.0.0 rake-0.8.7].each do |pkg|
      output.should include("Successfully installed #{pkg}")
      pkg.should be_fetched
      pkg.should be_unpacked
    end
  end

  it "installs valid gems while ignoring invalid ones" do
    bpm "install", "rake", "fake", :track_stderr => true

    stdout.read.should include("Successfully installed rake-0.8.7")
    stderr.read.should include("Can't find package fake")

    "rake-0.8.7".should be_fetched
    "rake-0.8.7".should be_unpacked
    "fake-0".should_not be_fetched
    "fake-0".should_not be_unpacked
  end

  it "fails when installing an invalid gem" do
    bpm "install", "fake", :track_stderr => true

    stderr.read.should include("Can't find package fake")
    "rake-0.8.7".should_not be_fetched
    "rake-0.8.7".should_not be_unpacked
    "fake-0".should_not be_fetched
    "fake-0".should_not be_unpacked
  end

  it "fails if bpm can't write to the bpm directory" do
    FileUtils.mkdir_p bpm_dir
    FileUtils.chmod 0555, bpm_dir

    bpm "install", "rake", :track_stderr => true
    exit_status.should_not be_success

    "rake-0.8.7".should_not be_fetched
    "rake-0.8.7".should_not be_unpacked
  end

  it "installs gems with a different version" do
    bpm "install", "rake", "-v", "0.8.6"

    stdout.read.should include("Successfully installed rake-0.8.6")

    "rake-0.8.7".should_not be_fetched
    "rake-0.8.7".should_not be_unpacked
    "rake-0.8.6".should be_fetched
    "rake-0.8.6".should be_unpacked
  end

  it "installs a valid prerelease package" do
    bpm "install", "bundler", "--pre"

    stdout.read.should include("Successfully installed bundler-1.1.pre")

    "bundler-1.1.pre".should be_fetched
    "bundler-1.1.pre".should be_unpacked
  end

  it "does not install the normal package when asking for a prerelease" do
    bpm "install", "rake", "--pre", :track_stderr => true

    stderr.read.should include("Can't find package rake")

    "rake-0.8.7".should_not be_fetched
    "rake-0.8.7".should_not be_unpacked
    "rake-0.8.6".should_not be_fetched
    "rake-0.8.6".should_not be_unpacked
  end

  it "requires at least one package to install" do
    bpm "install", :track_stderr => true
    stderr.read.should include("called incorrectly")
  end

  it "does not make a .gem directory" do
    bpm "install", "rake"
    wait
    home(".gem").exist?.should be_false
  end

  it "installs gem dependencies" do
    bpm "install", "core-test"

    output = stdout.read

    %w(ivory-0.0.1 optparse-1.0.1 core-test-0.4.3).each do |name|
      output.should include("Successfully installed #{name}")

      name.should be_fetched
      name.should be_unpacked
    end
  end

end
