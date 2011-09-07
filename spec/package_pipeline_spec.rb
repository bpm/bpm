require "spec_helper"

describe BPM::PackagePipeline do

  before do
    goto_home
    set_host
    start_fake(FakeGemServer.new)
    FileUtils.cp_r(project_fixture('coffee'), '.')
    cd home('coffee')
  end

  subject do
    project = BPM::Project.new home('coffee')
    BPM::Pipeline.new project
  end

  it "should get package pipelines for each package" do
    names = subject.package_pipelines.map { |pipeline| pipeline.package.name }
    # NOTE: We handlebars is so deeply nested to test a very specific issue with
    # formats that are re-provided at least twice by packages that have a transport.
    # There is currently a fix for this in BPM::PluginProcessor
    names.sort.should == %w(coffee coffee-script handlebars handlebars-format spade spade-handlebars)
  end

  it "should get an asset for the coffee file" do
    asset = subject.find_asset 'coffee/lib/main.js'
    asset.should_not be_nil
    asset.pathname.should == home('coffee', 'lib', 'main.coffee')
  end

end

