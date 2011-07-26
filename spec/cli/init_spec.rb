require "spec_helper"
require 'json'

describe "bpm init on existing directory" do

  before do
    goto_home
    set_host
    start_fake(FakeGemServer.new)

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

    dummy_project = {
      "name" => "custom_project",
      "bpm"  => "1.0.0"
    }

    File.open("new_project.json", 'w'){|f| f.print dummy_project.to_json }

    bpm 'init', '--skip' and wait # skip, since we can't test the prompt
    File.read("new_project.json").should == dummy_project.to_json
  end

  it "should not overwrite existing project file (with different name)" do

    dummy_project = {
      "name" => "custom_project",
      "bpm"  => "1.0.0"
    }

    File.open("package.json", 'w'){|f| f.print dummy_project.to_json }

    bpm 'init' and wait
    exit_status.should be_success

    File.read("package.json").should == dummy_project.to_json
    File.exists?('new_project.json').should_not be_true
  end

  it "should update the project with app but save other settings" do
    bpm 'init' and wait

    # write a custom property
    project_json = File.join @project_path, 'new_project.json'
    json = JSON.load File.read(project_json)
    json["custom_property"] = "I haz it"
    File.open(project_json, 'w') { |fd| fd << json.to_json }

    bpm 'init', '--app' and wait

    json = JSON.load File.read(project_json)
    json["custom_property"].should == "I haz it"
    json["bpm:build"]["bpm_libs.js"].should_not be_nil

  end

  it "should rebuild assets" do

    bpm 'init' and wait

    files = %w(bpm_libs.js bpm_styles.css).map do |fn|
      File.join(@project_path, 'assets', fn)
    end

    files.each do |path|
      FileUtils.mkdir_p File.dirname(path)
      File.open(path, 'w') { |fd| fd.print "Not valuable info!" }
    end

    bpm 'init' and wait

    files.each do |path|
      File.read(path).should_not include("Not valuable info!")
    end
  end

  it "should allow a name to be specified" do
    bpm 'init', '--name=DifferentName' and wait

    File.join(@project_path, "DifferentName.json").should exist
    File.join(@project_path, "new_project.json").should_not exist
  end

end

describe "bpm init on a non-existant directory" do

  describe "normal" do

    before do
      goto_home
      set_host
      start_fake(FakeGemServer.new)
      cd home
    end

    it "should create files" do
      bpm 'init', 'BpmTest'


      files = %w(LICENSE README.md index.html app/main.js BpmTest.json)
      generated_files = %w(assets/bpm_libs.js assets/bpm_styles.css)

      # output without coloration
      output = stdout.read.gsub(/\e\[\d+m/,'')

      files.each do |file|
        output.should =~ /create\s+#{file}$/
        home("bpm_test", *file.split('/')).should exist
      end

      generated_files.each do |file|
        home('bpm_test', *file.split('/')).should exist
      end
    end

    it "should allow a path to be specified" do
      bpm 'init', 'DifferentLocation', '--name=BpmTest' and wait

      home("DifferentLocation").should exist
      home("DifferentLocation", "BpmTest.json").should exist
      home("DifferentLocation", "DifferentLocation.json").should_not exist
      home("bpm_test").should_not exist
    end

  end

  describe "package templates" do

    describe "with custom generator" do

      before do
        goto_home
        set_host
        start_fake(FakeGemServer.new)
      end

      it "should create custom files" do
        bpm 'init', 'BpmTest', '--package=custom_generator'

        files = %w(lib lib/main.js app.js BpmTest.json)

        # output without coloration
        output = stdout.read.gsub(/\e\[\d+m/,'')

        files.each do |file|
          output.should =~ /create\s+#{file}$/
          home("bpm_test", file).should exist
        end
      end

      it "should create custom app.js with explicit generator" do
        bpm 'init', 'BpmTest', '--package=custom_generator' and wait

        File.read(home("bpm_test", "app.js")).should == "require('BpmTest/main.js')\n"
      end

      it "should create custom project.json without explicit generator" do
        bpm 'init', 'BpmTest', '--package=core-test' and wait

        File.read(home("bpm_test", "BpmTest.json")).should =~ /"core-test": "0.4.9"/
      end

    end

    describe "without custom generator" do

      before do
        goto_home
        set_host
        start_fake(FakeGemServer.new)
        cd home
      end

      it "should add package as a dependency even if it doesn't have custom generator" do
        bpm 'init', 'BpmTest', '--package=jquery' and wait

        File.read(home("bpm_test", "BpmTest.json")).should =~ /"dependencies": {\n\s+"jquery": "1.4.3"\n\s+}/
      end

    end

  end

end
