require "spec_helper"

describe BPM::Project, "project_file_path" do

  it "should return both project file paths" do
    path = File.expand_path('../fixtures/hello_world', __FILE__)
    expected = File.join(path, 'hello_world.json')
    BPM::Project.project_file_path(path).should == expected
  end

  it "should return [] on a package" do
    path = File.expand_path('../fixtures/core-test', __FILE__)
    BPM::Project.project_file_path(path).should == nil
  end

  it "should return [] on a project with no file" do
    path = File.expand_path('../fixtures/simple_hello', __FILE__)
    BPM::Project.project_file_path(path).should == nil
  end

end

describe BPM::Project, "is_project_root?" do

  it "should return true for a project path" do
    path = File.expand_path('../fixtures/hello_world', __FILE__)
    BPM::Project.is_project_root?(path).should == true
  end

  it "should return false for a package" do
    path = File.expand_path('../fixtures/core-test', __FILE__)
    BPM::Project.is_project_root?(path).should == false
  end
  
  it "should return true for a project with no project file" do
    path = File.expand_path('../fixtures/simple_hello', __FILE__)
    BPM::Project.is_project_root?(path).should == true
  end

end

describe BPM::Project, "nearest_project" do

  describe "standard project" do
    subject do
      File.expand_path('../fixtures/hello_world', __FILE__)
    end
    
    it "should return project instance for project path" do
      BPM::Project.nearest_project(nil, subject).path.should == subject
    end

    it "should return project instance for path inside of project" do
      path = File.join subject, 'lib'
      BPM::Project.nearest_project(nil, path).path.should == subject
    end
  end

  describe "simple project" do
    subject do
      File.expand_path('../fixtures/simple_hello', __FILE__)
    end
    
    it "should return project instance for project path" do
      BPM::Project.nearest_project(nil, subject).path.should == subject
    end

    it "should return project instance for path inside of project" do
      path = File.join subject, 'lib'
      BPM::Project.nearest_project(nil, path).path.should == subject
    end
  end

  it "should return nil for a package" do
    path = File.expand_path('../fixtures/core-test', __FILE__)
    BPM::Project.nearest_project(nil,path).should == nil
  end
  
end

describe BPM::Project, "#project_config" do

  describe "standard project" do
    subject do
      BPM::Project.new nil, File.expand_path('../fixtures/hello_world', __FILE__)
    end

    it "should return project config" do
      subject.project_config["name"].should == 'hello_world'
    end
    
  end

  describe "simple project" do
    subject do
      BPM::Project.new nil, File.expand_path('../fixtures/simple_hello', __FILE__)
    end

    it "should return project config" do
      subject.project_config["name"].should == "simple_hello"
    end
    
  end
  
end

