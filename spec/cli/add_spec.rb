require 'spec_helper'
require 'json'

describe 'bpm add' do
  
  before do
    goto_home
    set_host
    env["GEM_HOME"] = bpm_dir.to_s
    env["GEM_PATH"] = bpm_dir.to_s
    start_fake(FakeGemServer.new)
    FileUtils.cp_r(fixtures('hello_world'), '.')
    cd home('hello_world')
  end

  def has_dependency(package_name, package_version)
    json = JSON.parse File.read(home('hello_world', 'hello_world.json'))
    json['dependencies'][package_name].should == package_version
    
    # TODO: Verify actual packages are copied in as well.
    # TODO: Verify packages built into bpm_packages.js and css
  end

  def no_dependency(package_name)
    json = JSON.load File.read(home('hello_world', 'hello_world.json'))
    json['dependencies'][package_name].should == nil
    
    # TODO: Verify packages not added in to packages
    # TODO: Verify packages not built into bpm_packages.js and css
  end
  
  it "must be called from within a project" do
    cd home # outside of project
    bpm "add", "jquery", :track_stderr => true
    stderr.read.should include("inside of a bpm project")
  end
  
  # it "should add a new hard dependency" do
  #   bpm 'add', 'jquery'
  #   wait
  #   
  #   output = stdout.read
  #   output.should include('Added jquery (1.4.3)')
  #   has_dependency 'jquery', '1.4.3'
  # end
  # 
  # it "adds multiple package dependencies" do
  #   bpm "add", "jquery", "rake"
  # 
  #   output = stdout.read
  # 
  #   %w(jquery:1.4.3 rake:0.8.7).each do |pkg|
  #     pkg_name, pkg_version = pkg.split ':'
  #     output.should include("Added #{pkg_name} (#{pkg_version})")
  #     has_dependency pkg_name, pkg_version
  #   end
  # end
  # 
  # it "adds valid packages while ignoring invalid ones" do
  #   bpm "add", "jquery", "fake", :track_stderr => true
  # 
  #   stdout.read.should include("Added jquery (1.4.3)")
  #   stderr.read.should include("Can't find package fake")
  # 
  #   has_dependency 'jquery', '1.4.3'
  #   no_dependency 'fake'
  # end
  # 
  # it "fails when adding invalid package" do
  #   bpm "add", "fake", :track_stderr => true
  # 
  #   stderr.read.should include("Can't find package fake")
  #   no_dependency 'fake'
  # end
  # 
  # it "fails if bpm can't write to the json or packages directory" do
  #   FileUtils.mkdir_p home('hello_world', 'packages')
  #   FileUtils.chmod 0555, home('hello_world', 'packages')
  #   FileUtils.chmod 0555, home('hello_world', 'hello_world.json')
  # 
  #   bpm "add", "jquery", :track_stderr => true
  #   exit_status.should_not be_success
  #   no_dependency 'jquery'
  # end
  # 
  # it "adds packages with different versions" do
  #   bpm "add", "rake", "-v", "0.8.6"
  # 
  #   stdout.read.should include("Added rake (0.8.6)")
  #   has_dependency 'rake', '0.8.6'
  # end
  # 
  # it "updates a package to latest version" do
  #   bpm 'add', 'rake', '-v', '0.8.6'
  #   wait
  #   has_dependency 'rake', '0.8.6' # precond
  #   
  #   bpm 'add', 'rake'
  #   wait
  #   output = stdout.read
  #   output.should include('Added rake (0.8.7)')
  #   has_dependency 'rake', '0.8.7'
  # end
  
  it "adds a valid prerelease package" do
    bpm "add", "bundler", "--pre"
    wait
    stdout.read.should include("Added bundler (1.1.pre)")
    has_dependency 'bundler', '1.1.pre'
  end
  
  it "does not add the normal package when asking for a prerelease" do
    bpm "add", "rake", "--pre", :track_stderr => true
    wait
    stderr.read.should include("Can't find package rake")
    no_dependency 'rake'
  end

  # it "requires at least one package to add" do
  #   bpm "add", :track_stderr => true
  #   stderr.read.should include("at least one package")
  # end

    
end
