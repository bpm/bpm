require "spec_helper"

describe "bpm init" do

  before do
    @project_path = home("new_project")
    FileUtils.mkdir @project_path
    cd @project_path
  end

  it "should create files" do
    bpm 'init'

    files = %w(new_project.json assets assets/bpm_packages.js assets/bpm_styles.css)

    output = stdout.read.gsub(/\e\[\d+m/,'') #without colors

    files.each do |file|
      output.should =~ /create\s+#{file}$/
      File.join(@project_path, file).should exist
    end
  end

  it "should fetch dependencies"

  it "should build"

  it "should not overwrite existing files" do
    File.open("new_project.json", 'w'){|f| f.print "Valuable info!" }

    bpm 'init', '--skip' # skip, since we can't test the prompt

    output = stdout.read.gsub(/\e\[\d+m/,'') # without colors

    output.should =~ /skip\s+new_project.json/
    File.read("new_project.json").should == "Valuable info!"
  end

  it "should allow a name to be specified" do
    bpm 'init', '--name=DifferentName' and wait

    File.join(@project_path, "DifferentName.json").should exist
    File.join(@project_path, "new_project.json").should_not exist
  end

  it "should initialize multiple at once"

  it "should not allow a name when initializing multiple"

end
