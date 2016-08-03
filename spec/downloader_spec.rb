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
    expect {@downloader << {nourl: "this is not valid"}}.to raise_error(
      'Specify what you want to download as { url: \'http://location\' }'
    )
  end

  it 'raises exception when there is nothing to download' do
    expect { @downloader.start }.to raise_error "Nothing queued for download"
  end

  it "sets the download location" do
    expect(Downloader.new('target').directory).to eq('target')
  end

  it 'adds download url to list of downloads' do
    @downloader.add('download')
    expect(@downloader.downloads).to include({url: 'download'})
  end

  it 'adds md5 if passed' do
    @downloader.add('download', 'md5value') 
    expect(@downloader.downloads).to include({url: 'download', md5: 'md5value'})
  end

  it 'sets the url to be downloaded through a block' do
    downloader = Downloader.new  {|q|
      q.add 'firstdownload'
      q << { url: 'seconddownload' }
    }
    expect(downloader.downloads).to include({url: 'firstdownload'})
    expect(downloader.downloads).to include({url: 'seconddownload'})
  end

  it 'checks if the value appended is a HASH or nil' do
    expect {Downloader.new {|q| q << 'unsupported'}}.to raise_error (
      'Specify what you want to download as { url: \'http://location\' }'
    )  
  end
end

describe ZipFile do
  before :each do
    @extractor = double('zip_file')
    @zip_file = ZipFile.new 'file', extractor: @extractor  
  end

  it 'extracts to destination' do
    zip_file = double('z', each:['entry'])
    allow(@extractor).to receive(:open).and_yield(zip_file)
    expect(@extractor).to receive(:open)
      .with('file')
    @zip_file.extract_to('destination')
  end
end
