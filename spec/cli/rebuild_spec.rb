require 'spec_helper'
require 'json'

describe 'bpm compile' do
  
  describe 'complex dependencies' do

    before do
      goto_home
      set_host
      start_fake(FakeGemServer.new)
      FileUtils.cp_r(fixtures('projects', 'hello2'), '.')
      cd home('hello2')
    end

    it "should order the packages property with dependencies" do
      bpm 'rebuild', '--mode=debug' # avoid minification.
      wait
    
      file = File.read home('hello2', 'assets', 'bpm_libs.js')
      expected = <<EOF
/* ===========================================================================
   BPM Combined Asset File
   MANIFEST: a (1.0.0) b (1.0.0) c (1.0.0)
   This file is generated automatically by the bpm (http://www.bpmjs.org)    
   =========================================================================*/

// HELLO C

// HELLO B

// HELLO A

EOF

      file.should == expected
    end
  end

  describe 'development dependencies' do
    
    before do
      goto_home
      set_host
      start_fake(FakeGemServer.new)
      FileUtils.cp_r(project_fixture('hello_dev'), '.')
      cd home('hello_dev')

      bpm 'fetch'
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
    
    def test_development_dependencies(should_include)
      
      js_reg = [
        # fetch regular dependency
        %w(.bpm packages spade lib main.js)
      ]
      
      js_dev = [
        # fetched development dependency
        %w(.bpm packages uglify-js lib parse-js.js),
        
        # required dependency of development dependency
        %w(.bpm packages optparse lib optparse.js)
      ]
      
      css_dev = [
        # css of a locally installed development dependency
        %w(packages style_package css some_style.css)
      ]
    
      if should_include
        expected_manifest = 'optparse (1.0.1) spade (0.5.0) style_package (1.0.0) uglify-js (1.0.4)'
      else
        expected_manifest = 'spade (0.5.0)'
      end
      
      # validate manifest
      expected_manifest = "MANIFEST: #{expected_manifest}"
      File.read(home('hello_dev', 'assets', 'bpm_libs.js')).should include(expected_manifest)
      
      js_reg.each do |path|
        test_include true, 'bpm_libs.js', *path
      end
      
      js_dev.each do |path|
        test_include(should_include, 'bpm_libs.js', *path)
      end
      
      css_dev.each do |path|
        test_include(should_include, 'bpm_styles.css', *path)
      end
    end
    
    it "building in debug mode" do
      bpm 'rebuild', '--mode=debug'
      wait
      
      test_development_dependencies true
    end

    it "building in production mode" do
      bpm 'rebuild', '--mode=production'
      wait
      
      test_development_dependencies false
    end
    
  end
  
  describe "update" do
    
    before do
      goto_home
      set_host
      start_fake(FakeGemServer.new)
      FileUtils.cp_r project_fixture('needs_rake'), '.'
      cd home('needs_rake')
    end
  
    it "should not update dependencies with no-update if they can be met" do
      bpm 'fetch', 'rake', '--version=0.8.6' and wait
      bpm 'rebuild', '--no-update', '--verbose'
      out = stdout.read
      out.should_not include('Fetching packages from remote...')
      out.should include("'rake' (0.8.6)")
    end

    it "should update dependencies without no-update if they can be met" do
      bpm 'fetch', 'rake', '--version=0.8.6' and wait
      bpm 'rebuild', '--update', '--verbose'
      out = stdout.read
      out.should include('Fetching packages from remote...')
      out.should include("'rake' (0.8.7)")
    end

    it "should update dependencies with no-update if they cannot be met" do
      bpm 'rebuild', '--no-update', '--verbose'
      out = stdout.read
      out.should include('Fetching packages from remote...')
      out.should include("'rake' (0.8.7)")
    end
    
  end
  
  describe "error conditions" do
    
    before do
      goto_home
      set_host
      start_fake(FakeGemServer.new)
      FileUtils.cp_r(project_fixture('hello_dev'), '.')
      cd home('hello_dev')
    end
      
    it "should automatically recover if packages are damaged" do
      bpm 'rebuild' and wait 
      out = stdout.read
      out.should include('~ Building bpm_libs.js')
      
      FileUtils.rm_r home('.bpm') # delete linked directories.
      bpm 'rebuild', '--verbose', :track_stderr => true
      err = stderr.read
      err.should_not include('Could not find eligible')
    end
  end
      
end
