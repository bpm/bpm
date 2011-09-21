require 'spec_helper'
require 'json'

describe 'bpm remove' do

  before do
    goto_home
    set_host
    start_fake(FakeGemServer.new)
    FileUtils.cp_r(project_fixture('hello_world'), '.')
    cd home('hello_world')
    bpm 'fetch' # make sure existing packages are installed
    wait
  end

  it "should remove direct dependency from project" do
    bpm 'remove', 'spade'

    output = stdout.read
    output.should include("Removed package 'spade'")

    no_dependency 'spade'
    has_dependency 'core-test', '0.4.9', '0.4.9' # did not remove other dep
  end

  it "should remove soft dependencies" do
    bpm 'remove', 'core-test'
    wait

    output = stdout.read
    %w(core-test:0.4.9 ivory:0.0.1 optparse:1.0.1).each do |line|
      pkg_name, pkg_vers = line.split ':'
      output.should include("Removed package '#{pkg_name}'")
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
      output.should include("Removed package '#{pkg_name}'")
      no_dependency pkg_name
    end

    has_dependency 'ivory', '0.0.1', '0.0.1'

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

  it "should not uninstall local packages" do
    bpm 'add', 'custom_package'
    wait
    has_dependency 'custom_package', '2.0.0'

    bpm 'remove', 'custom_package'
    output = stdout.read

    no_dependency 'custom_package'
    File.exists?(home('hello_world', 'vendor', 'custom_package', 'package.json')).should be_true
  end

  it "should remove development dependencies"

end
