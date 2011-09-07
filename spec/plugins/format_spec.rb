require "spec_helper"

describe BPM::Pipeline, 'format' do

  before do
    goto_home
    set_host
    reset_libgems bpm_dir.to_s
    start_fake(FakeGemServer.new)

    FileUtils.cp_r project_fixture('coffee'), '.'
    cd home('coffee')

    bpm 'rebuild'
    wait
  end

  subject do
    File.read home('coffee', 'assets', 'bpm_libs.js')
  end

  it "should compile coffee file and wrap with transport" do
    subject.should include("spade(COFFEE(//coffee/lib/main\n))")
  end

  it "should compile handlebars template with transport" do
    subject.should include("spade(HANDLEBARS(//coffee/templates/section\n RUNTIME))")
  end

  it "should include coffeescript runtime" do
    subject.should include("//coffee-script/lib/main")
  end

  it "should include spade runtime" do
    subject.should include("//spade/lib/main")
  end

end
