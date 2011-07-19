require "spec_helper"

describe BPM::Pipeline, 'transport processor' do

  before do
    goto_home
    set_host
    reset_libgems bpm_dir.to_s
    start_fake(FakeGemServer.new)
    
    FileUtils.cp_r project_fixture('transporter'), '.'
    cd home('transporter')

    bpm 'rebuild'
    wait
  end
  
  subject do
    project = BPM::Project.new home('transporter')
    BPM::Pipeline.new project
  end
  
  it "should wrap the project's main.js" do
    asset = subject.find_asset 'transporter/lib/main.js'
    exp_path = home('transporter', 'lib', 'main.js')
    asset.to_s.should == "define_transport(function() {\n//TRANSPORT\ntransporter();\n//TRANSPORT\n\n}), 'transporter', 'main', '#{exp_path}');\n\n"
    asset.pathname.to_s.should == File.join(Dir.pwd, 'lib', 'main.js')
  end

  it "should not wrap transport/main.js" do
    asset = subject.find_asset 'transport/lib/main.js'
    asset.to_s.should == "// TRANSPORT DEMO\n"
  end

end
