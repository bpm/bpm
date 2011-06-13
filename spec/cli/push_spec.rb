require "spec_helper"

describe "spade push" do
  let(:api_key) { "deadbeef" }
  let(:creds)   { spade_dir("credentials") }

  before do
    goto_home
    set_host
    start_fake(FakeGemcutter.new(api_key))
  end

  context "with a good api key" do
    before do
      write_api_key(api_key)
    end

    it "registers a gem when sent with the right api key" do
      spade "package", "push", "../../spec/fixtures/rake-0.8.7.spd"

      stdout.read.should include("Successfully registered rake (0.8.7)")
    end
  end

  it "shows rejection message if wrong api key is supplied" do
    write_api_key("beefbeef")

    spade "package", "push", "../../spec/fixtures/rake-0.8.7.spd"

    stdout.read.should include("One cannot simply walk into Mordor!")
  end
end

describe "spade push without api key" do
  before do
    cd(home)
    env["HOME"] = home.to_s
    env["RUBYGEMS_HOST"] = "http://localhost:9292"
    write_api_key("beefbeef")
  end

  it "ignores files that don't exist" do
    spade "package", "push", "rake-1.0.0.spd"

    stdout.read.should include("No such file")
  end

  it "must push a valid gem" do
    spade "package", "push", "../../spec/fixtures/badrake-0.8.7.spd"

    stdout.read.should include("There was a problem opening your package.")
  end

  it "does not allow pushing of random files" do
    spade "package", "push", "../../Rakefile"

    stdout.read.should include("There was a problem opening your package.")
  end
end

describe "spade push without api key" do
  before do
    cd(home)
    env["HOME"] = home.to_s
    env["RUBYGEMS_HOST"] = "http://localhost:9292"
  end

  it "asks for login first if api key does not exist" do
    spade "package", "push", "../../spec/fixtures/rake-0.8.7.spd"

    stdout.read.should include("Please login first with `spade login`")
  end
end
