require './lib/downloader'

describe Downloader do
  before(:each) do
    @downloader = Downloader.new
  end
  it "stores the url to be downloaded" do
    url_to_be_downloaded = { url: "http://itemtobedownloaded" }
    @downloader << url_to_be_downloaded 
    expect(@downloader.downloads.first).to include(url_to_be_downloaded)
  end
  it "must have url" do
    expect {@downloader << {nourl: "this is not valid"}}.to raise_error "url to be downloaded not specified"
  end
  it "sets the file name from the url" do
    @downloader << { url: "http://download/something.zip" }
    expect(@downloader.downloads.first).to include({out: 'something.zip'})
  end
  it "sets the file name when passed a parameter" do
    @downloader << { url: "http://download/something.zip", out: 'out.zip' }
    expect(@downloader.downloads.first).to include({out: 'out.zip'})
  end
end
