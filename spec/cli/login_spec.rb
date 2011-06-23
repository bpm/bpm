require "spec_helper"

describe "bpm login" do
  let(:email)    { "email@example.com" }
  let(:password) { "secrets" }
  let(:api_key)  { "deadbeef" }
  let(:creds)    { bpm_dir("credentials") }

  before do
    goto_home

    fake = lambda { |env|
      [200, {"Content-Type" => "text/plain"}, [api_key]]
    }

    protected_fake = Rack::Auth::Basic.new(fake) do |user, pass|
      user == email && password == pass
    end

    LibGems.host = "http://localhost:9292"
    start_fake(protected_fake)
  end

  it "says email that user is logging in as" do
    bpm "login"
    input email
    input password
    output = stdout.read
    output.should include("Enter your BPM credentials.")
    output.should include("Logging in as #{email}...")
  end

  it "makes a request out for the api key and stores it in BPM_DIR/credentials" do
    bpm "login"
    input email
    input password

    stdout.read.should include("Logged in!")
    File.exist?(creds).should be_true
    YAML.load_file(creds)[:bpm_api_key].should == api_key
    YAML.load_file(creds)[:bpm_email].should == email
  end

  it "notifies user if bad creds given" do
    bpm "login", :track_stderr => true
    input email
    input "badpassword"
    sleep 1
    kill!

    stdout.read.should include("Incorrect email or password.")
    File.exist?(creds).should be_false
  end

  it "allows the user to retry if bad creds given" do
    bpm "login"
    input "bademail@example.com"
    input "badpassword"

    input email
    input password

    output = stdout.read.split("\n").select { |line| line.size > 0 }
    output[0].should include("Enter your BPM credentials.")
    output[3].should include("Logging in as bademail@example.com...")
    output[4].should include("Incorrect email or password.")
    output[5].should include("Enter your BPM credentials.")
    output[8].should include("Logging in as #{email}...")
    output[9].should include("Logged in!")

    File.exist?(creds).should be_true
    YAML.load_file(creds)[:bpm_api_key].should == api_key
    YAML.load_file(creds)[:bpm_email].should == email
  end

  it "will login with credentials provided as cli arguments" do
    bpm "login", "-u", email, "-p", password
    output = stdout.read
    output.should_not include("Enter your BPM credentials.")
    output.should include("Logging in as #{email}...")
  end
  
  it "will not retry on failure if username and password are provided as cli arguments" do
    bpm "login", "-u", email, "-p", "badpassword"
    output = stdout.read
    output.should_not include("Enter your BPM credentials.")
    output.should include("Logging in as #{email}...")
    output.should include("Incorrect email or password.")
  end
  
  it "will only prompt for username if password is provided" do
    bpm "login", "-p", password
    input email
    output = stdout.read
    output.should include("Enter your BPM credentials.")
    output.should include("Email:")
    output.should_not include("Password:")
    output.should include("Logging in as #{email}...")
  end
  
  it "will only prompt for password if username is provided" do
    bpm "login", "-u", email
    input password
    output = stdout.read
    output.should include("Enter your BPM credentials.")
    output.should_not include("Email:")
    output.should include("Password:")
    output.should include("Logging in as #{email}...")
  end
end
