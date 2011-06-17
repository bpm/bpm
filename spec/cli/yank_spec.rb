require "spec_helper"

describe "bpm yank" do
  let(:api_key) { "deadbeef" }
  let(:creds)   { bpm_dir("credentials") }

  before do
    goto_home
    set_host
    start_fake(FakeGemcutter.new(api_key))
  end

  context "with a good api key" do
    before do
      write_api_key(api_key)
    end

    it "yanks a gem when sent with the right api key" do
      bpm "yank", "core-test", "-v", "1.4.3"

      stdout.read.should include("Successfully yanked gem: core-test (1.4.3)")
    end

    it "must yank a valid gem" do
      bpm "yank", "blahblah", "-v", "0.0.1"

      stdout.read.should include("This gem could not be found")
    end

    it "does not yank a yanked gem" do
      bpm "yank", "core-test", "-v", "2.4.3"

      stdout.read.should include("The version 2.4.3 has already been yanked.")
    end
  end

  it "shows rejection message if wrong api key is supplied" do
    write_api_key("beefbeef")

    bpm "yank", "core-test", "-v", "1.4.3"

    stdout.read.should include("One cannot simply walk into Mordor!")
  end
end

describe "bpm yank without api key" do
  before do
    cd(home)
    env["HOME"] = home.to_s
    env["RUBYGEMS_HOST"] = "http://localhost:9292"
    write_api_key("beefbeef")
  end

  it "must require a version" do
    bpm "yank", "core-test"

    stdout.read.should include("Version required")
  end
end

describe "bpm yank without api key" do
  before do
    cd(home)
    env["HOME"] = home.to_s
    env["RUBYGEMS_HOST"] = "http://localhost:9292"
  end

  it "asks for login first if api key does not exist" do
    bpm "yank", "core-test", "-v", "1.4.3"

    stdout.read.should include("Please login first with `bpm login`")
  end
end
