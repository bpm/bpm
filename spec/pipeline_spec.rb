require "spec_helper"

describe BPM::Pipeline, "asset_path" do

  before do
    goto_home
    env["GEM_HOME"] = bpm_dir.to_s
    env["GEM_PATH"] = bpm_dir.to_s
    FileUtils.cp_r(fixtures('hello_world'), '.')
  end
  
  subject do
    project = BPM::Project.new home('hello_world')
    BPM::Pipeline.new project
  end
  
  it "should find any asset in the assets directory" do
    asset = subject.find_asset 'papa-smurf.jpg'
    asset.pathname.should == home('hello_world', 'assets', 'papa-smurf.jpg')
  end
  
  it "should find any asset in packages" do
    asset = subject.find_asset 'custom_package/assets/dummy.txt'
    asset.pathname.should == home('hello_world', 'packages', 'custom_package', 'assets', 'dummy.txt')
  end
  
  it "should find any asset in installed packages" do
    set_host
    env["GEM_HOME"] = bpm_dir.to_s
    env["GEM_PATH"] = bpm_dir.to_s
    start_fake(FakeGemServer.new)
    cd home('hello_world')
    
    bpm 'compile'
    wait
  
    asset = subject.find_asset 'core-test/resources/runner.css'
    asset.pathname.should == home('hello_world', 'packages', 'core-test', 'resources', 'runner.css')
  end
  
  describe "bpm_packages.js" do
  
    before do
      set_host
      env["GEM_HOME"] = bpm_dir.to_s
      env["GEM_PATH"] = bpm_dir.to_s
      start_fake(FakeGemServer.new)
      cd home('hello_world')
  
      bpm 'add', 'custom_package'
      wait
  
      @project = BPM::Project.new home('hello_world')
    end
    
    
    subject do
      BPM::Pipeline.new(@project).find_asset 'bpm_packages.js'
    end
    
    it "should return an asset of type BPM::GeneratedAsset" do
      subject.class.should == BPM::GeneratedAsset
    end
    
    it "should find the bpm_packages.js" do
      subject.pathname.should == home('hello_world', 'assets', 'bpm_packages.js')
    end
  
    it "should find bpm_packages as well" do
      BPM::Pipeline.new(@project).find_asset('bpm_packages').should == subject
    end
    
    it "should have a manifest line" do
      subject.to_s.should include('MANIFEST: spade (0.5.0) ivory (0.0.1) optparse (1.0.1) core-test (0.4.9) rake (0.8.6) custom_package (2.0.0)')
    end
    
    it "should include any required modules in the bpm_package.js" do
      subject.to_s.should include(File.read(home('hello_world', 'packages', 'custom_package', 'lib', 'main.js')))
    end
    
    it "should reference package.json directories when resolving modules" do
      subject.to_s.should include(File.read(home('hello_world', 'packages', 'custom_package', 'custom_dir', 'basic-module.js')))
    end
    
  end
  
  describe "bpm_styles.css" do
  
    before do
      goto_home
      set_host
      env["GEM_HOME"] = bpm_dir.to_s
      env["GEM_PATH"] = bpm_dir.to_s
      start_fake(FakeGemServer.new)
      cd home('hello_world')
  
      bpm 'add', 'custom_package'
      wait
    end
    
    subject do
      project = BPM::Project.new home('hello_world')
      BPM::Pipeline.new(project).find_asset 'bpm_styles.css'
    end
    
    it "should find bpm_styles.css" do
      subject.pathname.should == home('hello_world', 'assets', 'bpm_styles.css')
    end
    
    it "should include any required modules in the bpm_styles.css" do
      subject.to_s.should include(File.read(home('hello_world', 'packages', 'custom_package', 'css', 'sample_styles.css')))
    end
  
    it "should reference installed package styles as well" do
      subject.to_s.should include(File.read(home('hello_world', 'packages', 'core-test', 'resources', 'runner.css')))
    end
    
  end
  
  describe BPM::Pipeline, "buildable_assets" do
  
    before do
      set_host
      start_fake(FakeGemServer.new)
      cd home('hello_world')
  
      bpm 'add', 'custom_package', '--verbose'
      wait
      puts stdout.read

      @project = BPM::Project.new home('hello_world')
    end
    
    subject do
      BPM::Pipeline.new(@project).buildable_assets
    end
    
    def project(*asset_names)
      Pathname.new File.join @project.root_path, *asset_names
    end

    def find_asset(logical_path)
      subject.find { |x| x.logical_path == logical_path }
    end
    
    it "should include bpm_packages.js" do
      asset = find_asset 'bpm_packages.js'
      asset.should_not be_nil
      asset.pathname.should == project('assets', 'bpm_packages.js')
    end
    
    it "should include bpm_styles.css" do
      asset = find_asset 'bpm_styles.css'
      asset.should_not be_nil
      asset.pathname.should == project('assets', 'bpm_styles.css')
    end
    
    it "should include custom_package assets" do
      asset = find_asset 'custom_package/assets/dummy.txt'
      asset.should_not be_nil
      asset.pathname.should == project('packages', 'custom_package', 'assets', 'dummy.txt')
    end

    it "should include installed package assets" do
      asset = find_asset 'core-test/resources/runner.css'
      asset.should_not be_nil
      asset.pathname.should == project('packages', 'core-test', 'resources', 'runner.css')
    end
    
    it "should exclude libs" do
      asset = find_asset 'custom_package/assets/lib/main.js'
      asset.should be_nil
    end
    
  end

end

  