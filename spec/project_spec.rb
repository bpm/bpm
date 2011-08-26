require "spec_helper"

describe BPM::Project, "project_file_path" do

  it "should return project file path" do
    path = project_fixture('hello_world')
    expected = File.join(path, 'hello_world.json')
    BPM::Project.project_file_path(path).should == expected
  end

  it "should return nil on a package" do
    path = package_fixture('core-test')
    BPM::Project.project_file_path(path).should == nil
  end

  it "should return nil on a project with no file" do
    path = project_fixture('simple_hello')
    BPM::Project.project_file_path(path).should == nil
  end

  it "should return project path with different name" do
    path = project_fixture('custom_name')
    expected = File.join(path, 'MyProject.json')
    BPM::Project.project_file_path(path).should == expected
  end

end

describe BPM::Project, "is_project_root?" do

  it "should return true for a project path" do
    BPM::Project.is_project_root?(project_fixture('hello_world')).should == true
  end

  it "should return false for a package" do
    BPM::Project.is_project_root?(package_fixture('core-test')).should == false
  end
  
  it "should return true for a project with no project file" do
    BPM::Project.is_project_root?(project_fixture('simple_hello')).should == true
  end

end

describe BPM::Project, "nearest_project" do

  describe "standard project" do
    subject do
      project_fixture('hello_world').to_s # string not Pathname
    end
    
    it "should return project instance for project path" do
      BPM::Project.nearest_project(subject).root_path.should == subject
    end

    it "should return project instance for path inside of project" do
      path = File.join subject, 'lib'
      BPM::Project.nearest_project(path).root_path.should == subject
    end
  end

  describe "simple project" do
    subject do
      project_fixture('simple_hello').to_s # string not Pathname
    end
    
    it "should return project instance for project path" do
      BPM::Project.nearest_project(subject).root_path.should == subject
    end

    it "should return project instance for path inside of project" do
      path = File.join subject, 'lib'
      BPM::Project.nearest_project(path).root_path.should == subject
    end
  end

  it "should return nil for a package" do
    BPM::Project.nearest_project(package_fixture('core-test')).should == nil
  end
  
end

describe BPM::Project, "project metadata" do

  describe "standard project" do
    subject do
      BPM::Project.new project_fixture('hello_world')
    end

    it { should be_valid }

    it "should get project name" do
      subject.name.should == "hello_world"
    end
    
    it "should get a project version" do
      subject.version.should == "2.0.0"
    end
    
    it "should get dependencies" do
      subject.dependencies.should == {
        "spade" => "0.5.0",
        "core-test" => "0.4.9"
      }
    end

    it "should get development dependencies" do
      subject.dependencies_development.should == {
        "custom_generator" => "1.0",
        "jquery" => "1.4.3"
      }
    end

  end

  describe "project with different name" do
    before do
      goto_home
      FileUtils.cp_r project_fixture('hello_world'), 'HelloWorld2'
    end
    
    subject do
      BPM::Project.new home('HelloWorld2')
    end
    
    # packages do not allow the directory and "name" to be different. make 
    # sure project doesn't inherit this.
    it "should not raise exception when loading json" do
      lambda {
        subject.load_json
      }.should_not raise_error
    end
  end
  
  describe "simple project" do
    subject do
      BPM::Project.new project_fixture('simple_hello')
    end

    it { should be_valid }

    it "should get project name" do
      subject.name.should == "simple_hello"
    end

    
    it "should get a default version" do
      subject.version.should == "0.0.1"
    end
    
    # FIXME: Is this test even useful?
    it "should get dependencies read from bpm_libs.js file" do
      subject.dependencies.should == {
      }
    end
    
  end
  
end

describe BPM::Project, "converting" do
  subject do
    BPM::Project.nearest_project(project_fixture("hello_world")).as_json
  end

  it "should have bpm set to current compatible version" do
    subject["bpm"].should == BPM::COMPAT_VERSION
  end
end

describe BPM::Project, "package_and_module_from_path" do

  before do
    # This seems a bit overkill, but we need our dependencies installed
    goto_home
    set_host
    start_fake(FakeGemServer.new)
    FileUtils.cp_r(project_fixture('hello_world'), '.')
    cd home('hello_world')
  end

  subject do
    proj = BPM::Project.nearest_project('.')
    proj.fetch_dependencies
    proj
  end

  # TODO: Make into a nice matcher
  def check_package_and_module(proj, path, pkg_name, module_id)
    pkg, id = proj.package_and_module_from_path(path)
    pkg.name.should == pkg_name
    id.should == module_id
  end

  it "should find path in self" do
    check_package_and_module(subject, home("hello_world", "css", "dummy.css"),
                              "hello_world", "~css/dummy")
  end

  it "should find path in dependencies" do
    check_package_and_module(subject, home(".bpm", "gems", "core-test", "resources", "runner.css"),
                              "core-test", "~resources/runner")
  end

  it "should throw error if no package" do
    l = lambda{ subject.package_and_module_from_path(project_fixture("simple_hello")) }
    l.should raise_error(/simple_hello is not within a known package/)
  end

  it "should not match partial directories" do
    # We're verifying that core-testing doesn't match core-test
    # Since there is no core-testing package it will fall back to the base package, hello_world
    check_package_and_module(subject, home("hello_world", ".bpm", "packages", "core-testing", "resources", "runner.css"),
                              "hello_world", "~.bpm/packages/core-testing/resources/runner")
  end

  it "should handle directory reference in package directories array" do
    check_package_and_module(subject, home("hello_world", "lib", "main.js"),
                              "hello_world", "main")
    check_package_and_module(subject, home("hello_world", "vendor", "lib", "something.js"),
                              "hello_world", "something")
  end

  it "should replace with directory names" do
    check_package_and_module(subject, home("hello_world", "custom_dir", "custom.js"),
                              "hello_world", "~custom/custom")
  end

end
