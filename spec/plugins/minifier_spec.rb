require "spec_helper"

describe BPM::Pipeline, 'minifier' do

  before do
    goto_home
    set_host
    reset_libgems bpm_dir.to_s
    start_fake(FakeGemServer.new)

    FileUtils.cp_r project_fixture('minitest'), '.'
    cd home('minitest')

    bpm 'rebuild'
    wait
  end

  subject do
    project = BPM::Project.new home('minitest')
    BPM::Pipeline.new project, :production
  end

  it "should wrap bpm_libs.js" do
    asset = subject.find_asset 'bpm_libs.js'
    expected = <<EOF
/* ===========================================================================
   BPM Combined Asset File
   MANIFEST: (none)
   This file is generated automatically by the bpm (http://www.bpmjs.org)
   =========================================================================*/
//MINIFIED START
UGLY DUCK IS UGLYboston


//MINIFIED END
EOF

    asset.to_s.should == expected
  end

  it "should wrap app_package.js" do
    asset = subject.find_asset 'minitest/bpm_libs.js'
    file_path = home('minitest', 'lib', 'main.js')
    expected = <<EOF
/* ===========================================================================
   BPM Combined Asset File
   MANIFEST: minitest (2.0.0)
   This file is generated automatically by the bpm (http://www.bpmjs.org)
   =========================================================================*/
//MINIFIED START
UGLY DUCK IS UGLYsanfran

#{File.read(file_path)}
//MINIFIED END
EOF
    asset.to_s.should == expected
  end

  subject do
    project = BPM::Project.new home('minitest')
    BPM::Pipeline.new project, :production
  end

  it "should not wrap bpm_libs.js in debug mode" do
    project  = BPM::Project.new home('minitest')
    pipeline = BPM::Pipeline.new project, :debug
    asset    = pipeline.find_asset 'minitest/app_package.js'
    asset.to_s.should_not include('//MINIFIED START')
  end

end


