require "spec_helper"

describe "bpm new" do

  before do
    cd home
  end

  it "should create files" do
    bpm 'new', 'BpmTest'

    files = %w(LICENSE README.md lib tests lib/main.js tests/main-test.js BpmTest.json
                assets assets/bpm_packages.js assets/bpm_styles.css)

    # output without coloration
    output = stdout.read.gsub(/\e\[\d+m/,'')

    files.each do |file|
      output.should =~ /create\s+#{file}$/
      home("bpm_test", file).should exist
    end
  end

  it "should fetch dependencies"

  it "should build"

  it "should not generate into existing directory" do
    FileUtils.mkdir 'bpm_test'

    bpm 'new', 'BpmTest'

    stdout.read.should_not include("create")
    `ls #{home("bpm_test")}`.should be_empty
  end

  it "should allow a path to be specified" do
    bpm 'new', 'BpmTest', '--path=DifferentLocation' and wait

    home("DifferentLocation").should exist
    home("DifferentLocation", "BpmTest.json").should exist
    home("DifferentLocation", "DifferentLocation.json").should_not exist
    home("bpm_test").should_not exist
  end

end
