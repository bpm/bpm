require 'spec_helper'
require 'json'

describe 'bpm update' do
  
  before do
    goto_home
    set_host
    env["GEM_HOME"] = bpm_dir.to_s
    env["GEM_PATH"] = bpm_dir.to_s
    start_fake(FakeGemServer.new)
    FileUtils.cp_r(fixtures('hello_world'), '.')
    cd home('hello_world')
  end

  def no_package(*package_names)
    package_names.each do |package_name|
      pkg_path = home('hello_world', 'packages', package_name)
      File.exists?(pkg_path).should_not be_true
    end
  end
  
  def has_package(package_name, package_vers)
    pkg_path = home('hello_world', 'packages', package_name)
    File.exists?(pkg_path).should be_true
    pkg = BPM::Package.new(pkg_path)
    pkg.load_json
    pkg.version.should == package_vers
  end
  
  it "should install any packages mentioned in the project.json" do
    no_package 'spade', 'core-test', 'ivory'
    bpm 'update'
    wait

    has_package 'spade',     '0.5.0'
    has_package 'core-test', '0.4.9'
    has_package 'ivory',     '0.0.1'
    has_package 'optparse',  '1.0.1'
  end

  it "should have no effect when called multiple times" do
    bpm 'update'
    wait
    has_package 'spade', '0.5.0'
    
    dummy_path = home 'hello_world', 'packages', 'spade', 'dummy.txt'
    FileUtils.touch dummy_path

    bpm 'update'
    wait
    has_package 'spade', '0.5.0'
    File.exists?(dummy_path).should be_true # did not reinstall
  end
  
  # TODO: verify compile
  
end
