require 'spec_helper'
require 'json'

describe 'bpm compile' do
  
#   describe 'complex dependencies' do
# 
#     before do
#       goto_home
#       set_host
#       start_fake(FakeGemServer.new)
#       FileUtils.cp_r(fixtures('projects', 'hello2'), '.')
#       cd home('hello2')
#     end
# 
#     it "should order the packages property with dependencies" do
#       bpm 'compile', '--mode=debug' # avoid minification.
#       wait
#     
#       file = File.read home('hello2', 'assets', 'bpm_packages.js')
#       expected = <<EOF
# /* ===========================================================================
#    BPM Combined Asset File
#    MANIFEST: a (1.0.0) b (1.0.0) c (1.0.0)
#    This file is generated automatically by the bpm (http://www.bpmjs.org)    
#    =========================================================================*/
# 
# // HELLO C
# 
# // HELLO B
# 
# // HELLO A
# 
# EOF
# 
#       file.should == expected
#     end
#   end

  describe 'development dependencies' do
    
    before do
      goto_home
      set_host
      start_fake(FakeGemServer.new)
      FileUtils.cp_r(project_fixture('hello_dev'), '.')
      cd home('hello_dev')

      bpm 'fetch'
      wait
      
      bpm 'compile', '--mode=debug' # do not minify
      wait
    end
    
    def test_include(does_include, build_file, *source_file)
      contents_path = home('hello_dev', 'assets', build_file)
      expected_path = home('hello_dev', *source_file)

      if does_include
        File.read(contents_path).should include(File.read(expected_path))
      else
        File.read(contents_path).should_not include(File.read(expected_path))
      end
        
    end
    
    def in_dev_packages(*source_file)
      test_include(true,  'dev_packages.js', *source_file)
      test_include(false, 'bpm_packages.js', *source_file)
    end

    def in_bpm_packages(*source_file)
      test_include(false,  'dev_packages.js', *source_file)
      test_include(true, 'bpm_packages.js', *source_file)
    end
    
    def in_dev_styles(*source_file)
      test_include(true,  'dev_styles.css', *source_file)
      test_include(false, 'bpm_styles.css', *source_file)
    end

    def in_bpm_styles(*source_file)
      test_include(false,  'dev_styles.css', *source_file)
      test_include(true, 'bpm_styles.css', *source_file)
    end
          
    it "should add dev gems into dev js file" do
      in_dev_packages '.bpm', 'packages', 'uglify-js', 'lib', 'parse-js.js'
    end
    
    it "should not add main dependency to dev file" do
      in_bpm_packages '.bpm', 'packages', 'spade', 'lib', 'main.js'
    end
    
    it "should add dev css into dev css file" do
      in_dev_styles 'packages', 'style_package', 'css', 'some_style.css'
    end
    
    it "should include required deps not in main deps" do
      in_dev_packages '.bpm', 'packages', 'optparse', 'lib', 'optparse.js'
    end
    
  end
end
