require "spec_helper"

describe "bpm preview" do

  it "should work"

  it "should preserve json settings"
  # i.e. spade:format

end

describe "bpm preview with a package" do
  before do
    goto_home
    set_host
    start_fake(FakeGemServer.new)
    FileUtils.cp_r(package_fixture('spade'), '.')
    cd home('spade')
  end

  it "should preview package"
end
