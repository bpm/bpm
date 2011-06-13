require 'spec_helper'

describe Spade::Packager::Credentials do
  def new_creds
    Spade::Packager::Credentials.new
  end

  around do |example|
    cd(home)
    LibGems.send(:set_home, home)
    example.call
    LibGems.clear_paths
  end

  subject { new_creds }

  it "saves the api key and email" do
    subject.save("someone@example.com", "secrets")

    new_creds.api_key.should == "secrets"
    new_creds.email.should == "someone@example.com"
  end
end
