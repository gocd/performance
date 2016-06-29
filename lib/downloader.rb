class Downloader
  attr_reader :downloads

  def initialize
   @downloads = [] 
  end
  def <<(download)
    raise "url to be downloaded not specified" if !download[:url]
    download[:out] =  download[:out] || download[:url].split('/').last
    self.downloads << download 
  end
end
