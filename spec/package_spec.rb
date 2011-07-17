require "spec_helper"

describe BPM::Package do
  it "should have 'lib' as default lib_path'" do
    subject.send(:lib_path).should == 'lib'
  end

  it "should have 'tests' as default tests_path'" do
    subject.send(:tests_path).should == 'tests'
  end
end

describe BPM::Package, "#to_spec" do
  let(:email) { "user@example.com" }

  before do
    cd(home)
    FileUtils.mkdir_p(home("lib"))
    FileUtils.mkdir_p(home("resources"))
    FileUtils.mkdir_p(home("tests"))
  end

  subject do
    package = BPM::Package.new(nil, email)
    package.json_path = package_fixture("core-test", "package.json")
    if spec = package.to_spec
      spec
    else
      puts "Errors: #{package.errors}"
      nil
    end
  end

  def expand_sort(files)
    files.map { |f| File.expand_path(f) }.sort
  end

  it "transforms the name" do
    subject.name.should == "core-test"
  end

  it "transforms the version" do
    subject.version.should == LibGems::Version.new("0.4.9")
  end

  it "transforms the author" do
    subject.authors.should == ["Charles Jolley"]
  end

  it "transforms the email" do
    subject.email.should == email
  end

  it "transforms the homepage" do
    subject.homepage.should == "https://github.com/strobecorp/core-test"
  end

  it "transforms the description" do
    subject.description.should == "Flexible testing library for JavaScript."
  end

  it "transforms the description" do
    subject.summary.should == "A fully featured asynchronous testing library for JavaScript, compatible with other frameworks."
  end

  it "transforms the dependencies" do
    subject.dependencies.map{|d| [d.name, d.requirement]}.should == [["ivory", "= 0.0.1"], ["optparse", "= 1.0.1"]]
  end

  it "packs metadata into requirements" do
    metadata = JSON.parse(subject.requirements.first)
    metadata["licenses"].should == [
      {"type" => "MIT",
       "url"  => "https://github.com/strobecorp/core-test/raw/master/LICENSE"}
    ]
    metadata["engines"].should == ["browser", "all"]
    metadata["main"].should == "./lib/main"
    metadata["bin"].should == {"cot" => "./bin/cot"}
  end

  it "expands paths from the directories and bpm:build" do
    others     = ["tmp/blah.js", "tmp/whee.txt"]
    files      = ["bin/cot", "lib/main.js", "lib/core.js", "lib/test.js", "package.json", "resources/additions.css", "resources/runner.css", "index.html", "extras/extra_file.html"]
    test_files = ["tests/apis/core-test.js", "tests/system/test/assert-test.js"]

    FileUtils.mkdir_p(["bin/", "resources/", "lib/", "tests/apis", "tests/system/test", "tmp/", "extras/"])
    FileUtils.touch(files + test_files + others)

    expand_sort(subject.files).should == expand_sort(files + test_files)
    expand_sort(subject.test_files).should == expand_sort(test_files)
  end

  it "hacks the file name to return .bpkg" do
    subject.file_name.should == "core-test-0.4.9.bpkg"
  end

  it "sets the rubyforge_project to appease older versions of rubygems" do
    subject.rubyforge_project.should == "bpm"
  end
end

describe BPM::Package, "#to_s" do
  let(:email) { "user@example.com" }

  subject do
    package = BPM::Package.new
    package.json_path = package_fixture("core-test","package.json")
    package.valid?
    package
  end

  it "gives the name and version" do
    subject.full_name.should == "core-test-0.4.9"
  end
end

describe BPM::Package, "converting" do
  before do
    cd(home)
  end

  subject do
    package = BPM::Package.new
    package.fill_from_gemspec(fixtures('gems', "core-test-0.4.9.bpkg"))
    package.as_json
  end

  it "can recreate the same package.json from the package" do
    # These don't come out in the same order
    actual = Hash[subject.sort]
    expected = Hash[JSON.parse(File.read(package_fixture("core-test", "package.json"))).sort].reject{|k,v| v.empty? }
    actual.should == expected
  end
end

describe BPM::Package, "validating" do
  before do
    cd(home)
  end

  subject { BPM::Package.new }

  shared_examples_for "a good parser" do
    it "had a problem parsing package.json" do
      subject.should have_error("There was a problem parsing package.json")
    end
  end

  context "with a blank file" do
    before do
      FileUtils.touch("package.json")
      subject.json_path = "package.json"
    end
    it_should_behave_like "a good parser"
  end

  context "with bad json" do
    before do
      File.open("package.json", "w") do |f|
        f.write "---bad json---"
      end
      subject.json_path = "package.json"
    end
    it_should_behave_like "a good parser"
  end

  context "json can't be read" do
    before do
      FileUtils.cp package_fixture("core-test", "package.json"), "."
      FileUtils.chmod 0000, "package.json"
      subject.json_path = "package.json"
    end
    it_should_behave_like "a good parser"
  end

  context "json can't be found" do
    before do
      subject.json_path = "package.json"
    end
    it_should_behave_like "a good parser"
  end

end

describe BPM::Package, "validation errors" do
  let(:email) { "user@example.com" }

  before do
    cd(home)
    FileUtils.mkdir_p(home("lib"))
    FileUtils.mkdir_p(home("tests"))
  end

  subject do
    BPM::Package.new(nil, email)
  end

  def write_package
    path    = home("package.json")
    package = JSON.parse(File.read(package_fixture("core-test","package.json")))
    yield package
    File.open(path, "w") do |file|
      file.write package.to_json
    end
    subject.json_path = path
  end

  %w[name description summary homepage author version directories].each do |field|
    it "is invalid without a #{field} field" do
      write_package do |package|
        package.delete(field)
      end

      subject.should have_error("Package requires a '#{field}' field")
    end

    it "is invalid with a blank #{field} field" do
      write_package do |package|
        package[field] = ""
      end

      subject.should have_error("Package requires a '#{field}' field")
    end
  end

  it "is invalid without a proper version number" do
    write_package do |package|
      package["version"] = "bad"
    end

    subject.should have_error("Malformed version number string bad")
  end

  it "is valid without specifying a test directory" do
    write_package do |package|
      package["directories"].delete("tests")
    end

    subject.should be_valid
    subject.to_spec.test_files.should == []
  end

  it "is valid and has files without specifying bin" do
    write_package do |package|
      package.delete("bin")
    end

    subject.should be_valid
    subject.to_spec.files.should == ["package.json"]
  end

  %w(lib tests).each do |dir|
    it "is invalid if #{dir} points to a file" do
      FileUtils.touch(home("somefile"))
      write_package do |package|
        package["directories"][dir] = "./somefile"
      end

      subject.should have_error("'./somefile', specified for #{dir} directory, is not a directory")
    end

    it "is invalid with a #{dir} directory that doesn't exist" do
      write_package do |package|
        package["directories"][dir] = "nope"
      end

      subject.should have_error("'nope', specified for #{dir} directory, is not a directory")
    end

    it "is valid with a #{dir} directory that exists" do
      FileUtils.mkdir_p(home("somewhere", "else"))
      write_package do |package|
        package["directories"][dir] = "./somewhere/else"
      end

      subject.should be_valid
    end
  end

  it "is valid with a lib directory array" do
    FileUtils.mkdir_p(home("vendor/lib"))
    write_package do |package|
      package["directories"]["lib"] = ["./lib", "./vendor/lib"]
    end

    subject.should be_valid
  end

  it "is invalid if any lib directories don't exist" do
    write_package do |package|
      package["directories"]["lib"] = ["./lib", "./fake"]
    end

    subject.should have_error "'./fake', specified for lib directory, is not a directory"
  end

  it "is invalid if the lib directory array is empty" do
    write_package do |package|
      package["directories"]["lib"] = []
    end

    subject.should have_error("A lib directory is required")
  end

end

describe BPM::Package, "templates" do

  subject do
    package = BPM::Package.new(package_fixture("custom_generator"))
    package.load_json
    package
  end

  it "should have project template" do
    subject.template_path('project').should == package_fixture("custom_generator", "templates", "project").to_s
  end

end
