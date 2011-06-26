require 'spec_helper'
require 'json'

describe 'bpm remove' do
  
  before do
    goto_home
    set_host
    env["GEM_HOME"] = bpm_dir.to_s
    env["GEM_PATH"] = bpm_dir.to_s
    start_fake(FakeGemServer.new)
    FileUtils.cp_r(fixtures('hello_world'), '.')
    cd home('hello_world')
    bpm 'update' # make sure existing packages are installed 
    wait
  end
  
  def validate_dependency_in_project_file(package_name, package_version)
    json = JSON.parse File.read(home('hello_world', 'hello_world.json'))
    json['dependencies'][package_name].should == package_version
  end

  def validate_installed_dependency(package_name, package_version)
    pkg_path = home('hello_world', 'packages', package_name)
    if package_version
      File.exists?(pkg_path).should be_true
      pkg = BPM::Package.new(pkg_path)
      pkg.load_json
      pkg.version.should == package_version
    else
      File.exists?(pkg_path).should_not be_true
    end
  end
    
  def has_dependency(package_name, package_version)
    validate_dependency_in_project_file package_name, package_version
    validate_installed_dependency package_name, package_version
    # TODO: Verify packages built into bpm_packages.js and css
  end

  def has_soft_dependency(package_name, package_version)
    validate_dependency_in_project_file package_name, nil
    validate_installed_dependency package_name, package_version
    # TODO: Verify packages built into bpm_packages.js and css
  end
  
  def no_dependency(package_name)
    validate_dependency_in_project_file package_name, nil
    validate_installed_dependency package_name, nil
    # TODO: Verify packages not built into bpm_packages.js and css
  end
  
  it "should remove direct dependency from project" do
    bpm 'remove', 'spade'
    wait
    
    output = stdout.read
    output.should include("Removed unused package 'spade'")
    
    no_dependency 'spade'
    has_dependency 'core-test', '0.4.9' # did not remove other dep
  end

  it "should remove soft dependencies" do
    bpm 'remove', 'core-test'
    wait

    output = stdout.read
    %w(core-test:0.4.9 ivory:0.0.1 optparse:1.0.1).each do |line|
      pkg_name, pkg_vers = line.split ':'
      output.should include("Removed unused package '#{pkg_name}'")
      no_dependency pkg_name
    end
  end

  it "should remove soft dependencies only when they are no longer needed" do
    bpm 'add', 'ivory', '-v', '0.0.1', '--verbose' # make a hard dep
    wait
    
    bpm 'remove', 'core-test', '--verbose'
    wait

    output = stdout.read
    %w(core-test:0.4.9 optparse:1.0.1).each do |line|
      pkg_name, pkg_vers = line.split ':'
      output.should include("Removed unused package '#{pkg_name}'")
      no_dependency pkg_name
    end
    
    has_dependency 'ivory', '0.0.1'
    
    bpm 'remove', 'ivory'
    wait
    
    no_dependency 'ivory'
    
  end
  
  it "should do nothing when passed a non-existant dependency" do
    bpm 'remove', 'fake', :track_stderr => true
    wait
    
    output = stderr.read
    output.should include("'fake' is not a dependency")
  end
  
  
  
end
