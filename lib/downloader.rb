require 'uri'
require 'pathname'
require 'open-uri'
require 'digest/md5'
require 'pry'

class Downloader
  attr_reader :downloads, :directory

  def initialize(directory = "./")
    @downloads = [] 
    @directory = directory
    yield self if block_given?
  end

  def start
    raise "Nothing queued for download" if self.downloads.empty?
    self.downloads.each{ |download|
      uri = URI.parse(download[:url])
      download_file = File.basename(uri.path)
      download_path = Pathname.new(@directory) + download_file

      print "Downloading #{download_file}"
      File.open(download_path, "w+") do |f|
        IO.copy_stream(open(uri, 'rb'),f)
      end
      puts "..Done\n"

      if(download[:md5]) 
        if(download[:md5] != Digest::MD5::file(download_path).hexdigest) 
          raise "File #{download_file} did not finish downloading correctly" 
        end
        print "Verified md5: #{download[:md5]}\n"
      end
    }
  end

  def add(url, md5 = nil)
    download = { url: url }
    download[:md5] = md5 if md5
    self.downloads << download
  end

  def <<(download)
    raise "url to be downloaded not specified" if !download[:url]
    self.downloads << download 
  end

end
