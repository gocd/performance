require 'uri'
require 'pathname'
require 'open-uri'
require 'digest/md5'
require 'pry'
require 'zip'

class ZipFile
  def initialize(path, extractor: Zip::File)
    @path = path
    @extractor = extractor
  end

  def extractTo(destination)
    @extractor.open(@path) do |zip_file|
      zip_file.each {|entry| 
        target = Pathname.new(destination) + entry.name
        entry.extract target  if !File.exists? target 
      }
    end
  end
end

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

      yield(download_path.to_s.end_with?('.zip') ? ZipFile.new(download_path): download_path) if block_given?
    }
  end

  def add(url, md5 = nil)
    download = { url: url }
    download[:md5] = md5 if md5
    self.downloads << download
  end

  def <<(download)
    unless(download && download.is_a?(Hash) && download[:url]) 
      raise 'Specify what you want to download as { url: \'http://location\' }' 
    end
    self.downloads << download 
  end

end
