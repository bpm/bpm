require "spec_helper"

describe "BPM::PackageProject class" do
  it "should accept packages as project root" do
    BPM::PackageProject.is_project_root?(fixtures('packages', 'backbone')).should be_true
    BPM::PackageProject.is_project_root?(fixtures('projects', 'hello_world')).should be_false
    BPM::PackageProject.is_project_root?(fixtures('packages', 'non_existent')).should be_false
  end
end
