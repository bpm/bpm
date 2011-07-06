require 'spec_helper'
require 'json'

describe 'bpm compile - complex dependencies' do

  before do
    goto_home
    set_host
    start_fake(FakeGemServer.new)
    FileUtils.cp_r(fixtures('projects', 'hello2'), '.')
    cd home('hello2')
  end

  it "should order the packages property with dependencies" do
    bpm 'compile', '--mode=debug'
    wait
    
    file = File.read home('hello2', 'assets', 'bpm_packages.js')
    expected = <<EOF
/* ===========================================================================
   BPM Static Dependencies
   MANIFEST: a (1.0.0) b (1.0.0) c (1.0.0)
   This file is generated automatically by the bpm (http://www.bpmjs.org)    
   To use this file, load this file in your HTML head.
   =========================================================================*/

// HELLO C

// HELLO B

// HELLO A

EOF

    file.should == expected
  end
  
end