require "spec_helper"
require "libgems/format"

describe "bpm pack" do
  
  describe "when logged in" do
    let(:email) { "who@example.com" }
  
    before do
      goto_home
      write_creds(email, "deadbeef")
    end
  
    it "builds a bpm from a given package.json" do
      FileUtils.cp_r package_fixture("core-test"), "."
      cd "core-test"
      bpm "pack"
  
      exit_status.should be_success
      output = stdout.read
      output.should include("Successfully built package: core-test-0.4.9.bpkg")
  
      package = LibGems::Format.from_file_by_path("core-test-0.4.9.bpkg")
      package.spec.name.should == "core-test"
      package.spec.version.should == LibGems::Version.new("0.4.9")
      package.spec.email.should == email
    end

    it "should not complain about different directories" do
      FileUtils.cp_r package_fixture("core-test"), "custom-path"
      cd "custom-path"
      bpm "pack"

      exit_status.should be_success
      stdout.read.should include("Successfully built package: core-test-0.4.9.bpkg")
    end

  end
  
  describe "without logging in" do
    before do
      goto_home
    end
  
    it "pack a bpm from a given package.json" do
      FileUtils.cp_r package_fixture("core-test"), "."
      cd "core-test"
      bpm "pack", "-e", "joe@example.com"
  
      exit_status.should be_success
  
      package = LibGems::Format.from_file_by_path("core-test-0.4.9.bpkg")
      package.spec.name.should == "core-test"
      package.spec.version.should == LibGems::Version.new("0.4.9")
    end
  
    it "builds a bpm when given a path to a package" do
      FileUtils.cp_r package_fixture("core-test"), "."
      bpm "pack", "core-test", "-e", "joe@example.com"
  
      exit_status.should be_success
    
      cd 'core-test'
      package = LibGems::Format.from_file_by_path("core-test-0.4.9.bpkg")
      package.spec.name.should == "core-test"
      package.spec.version.should == LibGems::Version.new("0.4.9")
    end
  
    it "sets the email address if one is given" do
      FileUtils.cp_r package_fixture("core-test"), "."
      cd "core-test"
      bpm "pack", "-e", "lucy@allen.com"
  
      exit_status.should be_success
      output = stdout.read
  
      package = LibGems::Format.from_file_by_path("core-test-0.4.9.bpkg")
      package.spec.name.should == "core-test"
      package.spec.version.should == LibGems::Version.new("0.4.9")
      package.spec.email.should == "lucy@allen.com"
    end
  end
  
  describe "with an invalid package.json" do
    before do
      goto_home
      write_api_key("deadbeef")
    end
  
    it "reports error messages" do
      FileUtils.touch "package.json"
      bpm "pack", :track_stderr => true
  
      exit_status.should_not be_success
      output = stderr.read
      output.should include("There was a problem parsing package.json")
    end
  end
  
  describe "npm-compatible package" do
    before do
      goto_home
      FileUtils.cp_r package_fixture("backbone"), "."
      cd home("backbone")
      bpm "pack", :track_stderr => true and wait
    end
  
    it "successfully packs" do
      exit_status.should be_success
    end
  
    it "gets name and version" do
      package = LibGems::Format.from_file_by_path("backbone-0.5.1.bpkg")
      package.spec.name.should == "backbone"
      package.spec.version.should == LibGems::Version.new("0.5.1")
    end
  
    it "gets the homepage" do
      package = LibGems::Format.from_file_by_path("backbone-0.5.1.bpkg")
      package.spec.homepage.should == 'http://documentcloud.github.com/backbone/'
    end
   
  end
  
  describe "package with plugins" do
    before do
      goto_home
      FileUtils.cp_r project_fixture('coffee', 'packages'), '.'
    end
    
    it "should pack transports" do
      cd home('packages', 'spade')
      bpm "pack" and wait
      puts stdout.read
      exit_status.should be_success
      
      package = LibGems::Format.from_file_by_path 'spade-1.0.0.bpkg'
      package.spec.files.should include('lib/main.js')
      package.spec.files.should include('transport.js')
    end
  end
  
end

    
