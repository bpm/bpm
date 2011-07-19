require "spec_helper"

describe BPM::Pipeline, "asset_path" do

  before do
    goto_home
    set_host
    start_fake(FakeGemServer.new)
    FileUtils.cp_r(project_fixture('hello_world'), '.')
    cd home('hello_world')
  end
  
  subject do
    project = BPM::Project.new home('hello_world')
    BPM::Pipeline.new project
  end
  
  it "should find any asset in the assets directory" do
    bpm 'rebuild', '--update' and wait
    asset = subject.find_asset 'papa-smurf.jpg'
    asset.pathname.should == home('hello_world', 'assets', 'papa-smurf.jpg')
  end
  
  it "should find any asset in packages" do
    bpm 'fetch' and wait
    bpm 'add', 'custom_package' and wait
    
    asset = subject.find_asset 'custom_package/assets/dummy.txt'
    asset.pathname.should == home('hello_world', '.bpm', 'packages', 'custom_package', 'assets', 'dummy.txt')
  end
  
  it "should find any asset in installed packages" do
    bpm 'fetch' and wait
    bpm 'rebuild' and wait
  
    asset = subject.find_asset 'core-test/resources/runner.css'
    asset.pathname.should == home('hello_world', '.bpm', 'packages', 'core-test', 'resources', 'runner.css')
  end
  
  describe "generated assets" do

    before do
      bpm 'fetch' and wait
      bpm 'add', 'custom_package' and wait

      @project = BPM::Project.new home('hello_world')
    end

    describe "bpm_libs.js" do
      
      subject do
        BPM::Pipeline.new(@project).find_asset 'bpm_libs.js'
      end
    
      it "should return an asset of type BPM::GeneratedAsset" do
        subject.class.should == BPM::GeneratedAsset
      end
    
      it "should find the bpm_libs.js" do
        subject.pathname.should == home('hello_world', 'assets', 'bpm_libs.js')
      end
      
      it "should find bpm_libs as well" do
        BPM::Pipeline.new(@project).find_asset('bpm_libs').should == subject
      end
    
      it "should have a manifest line" do
        # Right now we're including dev deps
        subject.to_s.should include('MANIFEST: core-test (0.4.9) custom_generator (1.0) custom_package (2.0.0) ivory (0.0.1) jquery (1.4.3) optparse (1.0.1) rake (0.8.6) spade (0.5.0)')
      end
    
      it "should include any required modules in the bpm_package.js" do
        subject.to_s.should include(File.read(home('hello_world', 'packages', 'custom_package', 'lib', 'main.js')))
      end
    
      it "should reference package.json directories when resolving modules" do
        subject.to_s.should include(File.read(home('hello_world', 'packages', 'custom_package', 'custom_dir', 'basic-module.js')))
      end
    
    end
      
    describe "bpm_styles.css" do
      
      subject do
        BPM::Pipeline.new(@project).find_asset 'bpm_styles.css'
      end
    
      it "should find bpm_styles.css" do
        subject.pathname.should == home('hello_world', 'assets', 'bpm_styles.css')
      end
    
      it "should include any required modules in the bpm_styles.css" do
        subject.to_s.should include(File.read(home('hello_world', 'packages', 'custom_package', 'css', 'sample_styles.css')))
      end
      
      it "should reference installed package styles as well" do
        subject.to_s.should include(File.read(home('hello_world', '.bpm', 'packages', 'core-test', 'resources', 'runner.css')))
      end
    
    end
    
    describe "hello_world/bpm_libs.js" do
  
      subject do
        BPM::Pipeline.new(@project).find_asset 'hello_world/bpm_libs.js'
      end
    
      it "should return an asset of type BPM::GeneratedAsset" do
        subject.class.should == BPM::GeneratedAsset
      end
          
      it "should find the bpm_libs.js" do
        subject.pathname.should == home('hello_world', 'assets', 'hello_world', 'bpm_libs.js')
      end
        
      it "should find bpm_libs as well" do
        BPM::Pipeline.new(@project).find_asset('hello_world/bpm_libs').should == subject
      end
    
      it "should have a manifest line" do
        subject.to_s.should include('MANIFEST: hello_world (2.0.0)')
      end
    
      it "should include any required modules in the bpm_libs" do
        subject.to_s.should include(File.read(home('hello_world', 'lib', 'main.js')))
      end
    end

    describe "hello_world/bpm_styles.css" do
    
      before do
        FileUtils.mkdir_p home('hello_world', 'assets', 'hello_world')
        FileUtils.touch home('hello_world', 'assets', 'hello_world', 'bpm_styles.css')
      end
    
      subject do
        BPM::Pipeline.new(@project).find_asset 'hello_world/bpm_styles.css'
      end
    
      it "should return an asset of type BPM::GeneratedAsset" do
        subject.class.should == BPM::GeneratedAsset
      end
    
      it "should find the app_styles.css" do
        subject.pathname.should == home('hello_world', 'assets', 'hello_world', 'bpm_styles.css')
      end
    
      it "should find bpm_styles as well" do
        BPM::Pipeline.new(@project).find_asset('hello_world/bpm_styles').should == subject
      end
    
      it "should have a manifest line" do
        subject.to_s.should include('MANIFEST: hello_world (2.0.0)')
      end
    
      it "should include any required modules in the bpm_styles" do
        subject.to_s.should include(File.read(home('hello_world', 'css', 'dummy.css')))
      end
    
    end
    
    describe "hello_world/app_tests.js" do
    
      before do
        FileUtils.mkdir_p home('hello_world', 'assets', 'hello_world')
        FileUtils.touch home('hello_world', 'assets', 'hello_world', 'app_tests.js')
      end
    
      subject do
        BPM::Pipeline.new(@project).find_asset 'hello_world/bpm_tests.js'
      end
    
      it "should return an asset of type BPM::GeneratedAsset" do
        subject.class.should == BPM::GeneratedAsset
      end
    
      it "should find the app_tests.js" do
        subject.pathname.should == home('hello_world', 'assets', 'hello_world', 'bpm_tests.js')
      end
    
      it "should find app_tests as well" do
        BPM::Pipeline.new(@project).find_asset('hello_world/bpm_tests').should == subject
      end
    
      it "should have a manifest line" do
        subject.to_s.should include('MANIFEST: hello_world (2.0.0)')
      end
    
      it "should include any required modules in the bpm_tests" do
        subject.to_s.should include(File.read(home('hello_world', 'tests', 'main-test.js')))
      end
    
    end
    
  end
  
end


describe BPM::Pipeline, "buildable_assets" do

  before do
    set_host
    goto_home
    FileUtils.cp_r(project_fixture('hello_world'), '.')
    reset_libgems bpm_dir.to_s

    start_fake(FakeGemServer.new)
    cd home('hello_world')

    bpm 'fetch' and wait
    bpm 'add', 'custom_package', '--verbose' and wait

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
  
  it "should include bpm_libs.js" do
    asset = find_asset 'bpm_libs.js'
    asset.should_not be_nil
    asset.pathname.should == project('assets', 'bpm_libs.js')
  end
  
  it "should include bpm_styles.css" do
    asset = find_asset 'bpm_styles.css'
    asset.should_not be_nil
    asset.pathname.should == project('assets', 'bpm_styles.css')
  end
  
  it "should include custom_package assets" do
    asset = find_asset 'custom_package/assets/dummy.txt'
    asset.should_not be_nil
    asset.pathname.should == project('.bpm', 'packages', 'custom_package', 'assets', 'dummy.txt')
  end
  
  it "should include installed package assets" do
    asset = find_asset 'core-test/extras/extra_file.html'
    asset.should_not be_nil
    asset.pathname.should == project('.bpm', 'packages', 'core-test', 'extras', 'extra_file.html')
  end
  
  it "should exclude libs" do
    asset = find_asset 'custom_package/assets/lib/main.js'
    asset.should be_nil
  end
  
end
 
