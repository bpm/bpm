require "spec_helper"

describe "bpm unpack" do
  before do
    goto_home
  end

  it "builds a gem from a given package.json" do
    FileUtils.cp fixtures("coffee-1.0.1.pre.bpkg"), "."
    bpm "unpack", "coffee-1.0.1.pre.bpkg"

    exit_status.should be_success
    output = stdout.read
    output.should include("Unpacked package into: #{Dir.pwd}/coffee-1.0.1.pre")

    home("coffee-1.0.1.pre/bin/coffee").should exist
    home("coffee-1.0.1.pre/lib/coffee.js").should exist
    home("coffee-1.0.1.pre/lib/coffee/base.js").should exist
    home("coffee-1.0.1.pre/lib/coffee/mocha/chai.js").should exist
    home("coffee-1.0.1.pre/qunit/coffee/test.js").should exist
    home("coffee-1.0.1.pre/qunit/test.js").should exist
  end

  it "can unpack to a different directory" do
    FileUtils.cp fixtures("coffee-1.0.1.pre.bpkg"), "."
    bpm "unpack", "coffee-1.0.1.pre.bpkg", "--target", "star/bucks"

    exit_status.should be_success
    output = stdout.read
    output.should include("Unpacked package into: #{Dir.pwd}/star/bucks/coffee-1.0.1.pre")

    home("star/bucks/coffee-1.0.1.pre/bin/coffee").should exist
  end

  it "can unpack more than one package" do
    FileUtils.cp fixtures("coffee-1.0.1.pre.bpkg"), "."
    FileUtils.cp fixtures("jquery-1.4.3.bpkg"), "."
    bpm "unpack", "coffee-1.0.1.pre.bpkg", "jquery-1.4.3.bpkg"

    exit_status.should be_success
    output = stdout.read
    output.should include("Unpacked package into: #{Dir.pwd}/coffee-1.0.1.pre")
    output.should include("Unpacked package into: #{Dir.pwd}/jquery-1.4.3")

    home("coffee-1.0.1.pre", "bin", "coffee").should exist
    home("jquery-1.4.3", "lib", "main.js").should exist
  end

  it "shows a friendly error message if bpm can't write to the given directory" do
    FileUtils.mkdir_p(home("bad"))
    cd(home("bad"))
    FileUtils.cp fixtures("jquery-1.4.3.bpkg"), "."
    FileUtils.chmod 0555, "."
    bpm "unpack", "jquery-1.4.3.bpkg", :track_stderr => true

    exit_status.should_not be_success
    output = stderr.read
    output.should include("There was a problem unpacking jquery-1.4.3.bpkg:")
    output.should include("Permission denied")
  end

  it "shows a friendly error message if bpm can't read the package" do
    FileUtils.cp fixtures("jquery-1.4.3.bpkg"), "."
    FileUtils.chmod 0000, "jquery-1.4.3.bpkg"
    bpm "unpack", "jquery-1.4.3.bpkg", :track_stderr => true

    exit_status.should_not be_success
    output = stderr.read
    output.should include("There was a problem unpacking jquery-1.4.3.bpkg:")
    output.should include("Permission denied")
  end
end
