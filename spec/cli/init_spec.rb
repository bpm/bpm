require "spec_helper"
require 'json'

describe "bpm init" do

  before do
    @project_path = home("new_project").to_s
    FileUtils.mkdir @project_path
    cd @project_path
  end

  # compare the generated project to a fixture template
  def compare_to(project_name)
    compare_contents @project_path, project_fixture(project_name)
  end
  
  it "should create files" do
    bpm 'init' and wait
    compare_to 'init_default'
  end

  it "should create app files with --app option" do
    bpm 'init', '--app' and wait
    compare_to 'init_app'
  end
  
  it "should not overwrite existing project file" do
    File.open("new_project.json", 'w'){|f| f.print "Valuable info!" }
  
    bpm 'init', '--skip' # skip, since we can't test the prompt
  
    output = stdout.read.gsub(/\e\[\d+m/,'') # without colors
  
    output.should =~ /skip\s+new_project.json/
    File.read("new_project.json").should == "Valuable info!"
  end

  it "should update the project with app but save other settings" do
    bpm 'init' and wait
    
    # write a custom property
    project_json = File.join @project_path, 'new_project.json'
    json = JSON.load File.read(project_json)
    json["custom_property"] = "I haz it"
    File.open(project_json, 'w') { |fd| fd << json.to_json }

    bpm 'init', '--skip', '--app' and wait
    
    app_package = home 'new_project', 'assets', 'new_project', 'app_package.js'
    File.exists?(app_package).should be_true
    
    json = JSON.load File.read(project_json)
    json["custom_property"].should == "I haz it"
    json["build"]["app"].should == true
    
  end
  
  it "should rebuild assets" do

    files = %w(bpm_packages.js bpm_styles.css).map do |fn| 
      File.join(@project_path, 'assets', fn)
    end
    
    files.each do |path|
      FileUtils.mkdir_p File.dirname(path)
      File.open(path, 'w') { |fd| fd.print "Not valuable info!" }
    end
    
    bpm 'init', '--skip' and wait
    
    files.each do |path|
      File.read(path).should_not include("Not valuable info!")
    end
  end
  
  it "should allow a name to be specified" do
    bpm 'init', '--name=DifferentName' and wait
  
    File.join(@project_path, "DifferentName.json").should exist
    File.join(@project_path, "new_project.json").should_not exist
  end

  # it "should initialize multiple at once"
  # 
  # it "should not allow a name when initializing multiple"

end
