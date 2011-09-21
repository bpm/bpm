require 'spec_helper'
require 'json'

describe 'bpm add' do

  before do
    goto_home
    set_host
    start_fake(FakeGemServer.new)
    FileUtils.cp_r(project_fixture('hello_world'), '.')
    cd home('hello_world')

    bpm 'fetch'
    wait
  end

  it "must be called from within a project" do
    cd home # outside of project
    bpm "add", "jquery", :track_stderr => true
    stderr.read.should include("inside of a BPM project")
  end

  it "should add a new hard dependency" do
    bpm 'add', 'jquery'
    wait

    output = stdout.read
    output.should include("Added package 'jquery' (1.4.3)")
    has_dependency 'jquery', '1.4.3'
  end

  it "adds multiple package dependencies" do
    bpm "add", "jquery", "rake"

    output = stdout.read

    %w(jquery:1.4.3 rake:0.8.7).each do |pkg|
      pkg_name, pkg_version = pkg.split ':'
      output.should include("Added package '#{pkg_name}' (#{pkg_version})")
      has_dependency pkg_name, pkg_version
    end
  end

  it "installs hard and soft dependencies" do
    bpm 'add', 'coffee', '--pre'
    wait

    output = stdout.read

    output.should include("Added package 'coffee' (1.0.1.pre)")
    output.should include("Added package 'jquery' (1.4.3)")

    has_dependency 'coffee', '1.0.1.pre', '>= 0.pre'
    has_soft_dependency 'jquery', '1.4.3'
  end

  it "adds no packages when any are invalid" do
    bpm "add", "jquery", "fake", :track_stderr => true

    stderr.read.should include("Could not find eligible package for 'fake' (>= 0)")

    no_dependency 'jquery'
    no_dependency 'fake'
  end

  it "fails when adding invalid package" do
    bpm "add", "fake", :track_stderr => true

    stderr.read.should include("Could not find eligible package for 'fake' (>= 0)")
    no_dependency 'fake'
  end

  it "fails if bpm can't write to the json or packages directory" do
    FileUtils.mkdir_p home('hello_world', 'packages')
    FileUtils.chmod 0555, home('hello_world', 'packages')
    FileUtils.chmod 0555, home('hello_world', 'hello_world.json')

    bpm "add", "jquery", :track_stderr => true
    exit_status.should_not be_success
    no_dependency 'jquery'

    FileUtils.chmod 0755, home('hello_world', 'packages')
    FileUtils.chmod 0755, home('hello_world', 'hello_world.json')
  end

  it "adds packages with different versions" do
    bpm "add", "rake", "-v", "0.8.6"

    stdout.read.should include("Added package 'rake' (0.8.6)")
    has_dependency 'rake', '0.8.6', '0.8.6'
  end

  it "updates a package to latest version" do
    bpm 'add', 'rake', '-v', '0.8.6'
    wait
    has_dependency 'rake', '0.8.6', '0.8.6' # precond

    bpm 'add', 'rake'
    wait

    output = stdout.read
    output.should_not include('Fetched spade') # not required 2nd time
    output.should_not include("Added package 'spade' (0.5.0)")
    output.should include("Added package 'rake' (0.8.7)")
    has_dependency 'rake', '0.8.7'
  end

  it "adds a valid prerelease package" do
    bpm "add", "bundler", "--pre", "--verbose"
    wait
    output = stdout.read
    output.should include("Added package 'bundler' (1.1.pre)")
    has_dependency 'bundler', '1.1.pre', '>= 0.pre'
  end

  it "does not add the normal package when asking for a prerelease" do
    bpm "add", "rake", "--pre", :track_stderr => true
    wait
    stderr.read.should include("Could not find eligible package for 'rake' (>= 0.pre)")
    no_dependency 'rake'
  end

  it "requires at least one package to add" do
    bpm "add", :track_stderr => true
    stderr.read.should include("at least one package")
  end

  it "should make a soft dependency a hard dependency" do
    bpm 'rebuild'
    wait
    has_soft_dependency 'ivory', '0.0.1'  # precond

    bpm 'add', 'ivory'
    wait
    has_dependency 'ivory', '0.0.1'
  end

  it "should use local package if available" do
    no_dependency 'custom_package'

    bpm "add", "custom_package"
    output = stdout.read

    output.should include("Using local package 'custom_package'")
    has_dependency 'custom_package', '2.0.0'
    has_soft_dependency 'rake', '0.8.6'
  end

  it "should fail if local package version is not compatible" do
    bpm "add", "custom_package", "-v", "3.0.0", :track_stderr => true
    output = stderr.read
    output.should include("'custom_package' (2.0.0) is not compatible")
    no_dependency 'custom_package'
  end

  it "should add local prerelease package" do
    no_dependency 'prerelease_package'

    bpm "add", "prerelease_package", "--pre"
    output = stdout.read

    output.should include("Using local package 'prerelease_package'")
    has_dependency 'prerelease_package', '1.0.0.pre', '>= 0.pre'
  end

  it "should work with .bpkg file" do
    FileUtils.cp fixtures('gems', "custom_generator-1.0.bpkg"), '.'
    bpm "add", "custom_generator-1.0.bpkg" and wait
    output = stdout.read
    output.should include("Added package 'custom_generator' (1.0)")
    has_dependency 'custom_generator', '1.0', '1.0'
  end

  describe "--dev" do

    it "should add as a development dependency" do
      bpm "add", "custom_generator", "--dev" and wait
      output = stdout.read
      output.should include("Added development package 'custom_generator' (1.0)")
      
      bpm 'rebuild', '--mode=debug' and wait
      has_development_dependency 'custom_generator', '1.0'
      no_dependency 'custom_generator', false
    end

  end

end

describe "bpm add using a vendor directory" do
  before do 
    goto_home
    set_host
    start_fake(FakeGemServer.new)
    FileUtils.cp_r project_fixture('hello_dev'), '.'
    FileUtils.mkdir_p home('hello_dev', 'vendor')
    FileUtils.cp_r project_fixture('hello_world'), home('hello_dev', 'vendor', 'hello_world')
    cd home('hello_dev')
  end
  
  it "should include custom_package defined in a project found vendor" do
    bpm 'add', 'custom_package' and wait
    
    File.read(home('hello_dev', 'assets', 'bpm_libs.js')).should include("custom_package (2.0.0)")
  end
    
end

