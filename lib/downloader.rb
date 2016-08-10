require 'uri'
require 'pathname'
require 'open-uri'
require 'digest/md5'
require 'zip'

# Zip file extractor
class ZipFile
  def initialize(path, extractor: Zip::File)
    @path = path
    @extractor = extractor
  end

  def extract_to(destination)
    @extractor.open(@path) do |zip_file|
      zip_file.each do |entry|
        target = Pathname.new(destination) + entry.name
        entry.extract target unless File.exist? target
      end
    end
  end
end

# Download files after adding them to a queue
class Downloader
  attr_reader :downloads, :directory

  def initialize(directory = './')
    @downloads = []
    @directory = directory
    yield self if block_given?
  end

  def start
    raise 'Nothing queued for download' if @downloads.empty?
    @downloads.each do |download|
      uri = URI.parse(download[:url])
      file, path = extract_file_and_path(download[:url])

      print "Downloading #{file}"
      File.open(path, 'w+') do |f|
        IO.copy_stream(open(uri, 'rb'), f)
      end
      puts '..Done'

      verify_md5(download[:md5], path)

      if block_given?
        yield path.to_s.end_with?('.zip') ? ZipFile.new(path) : path
      end
    end
  end

  def add(url, md5 = nil)
    download = { url: url }
    download[:md5] = md5 if md5
    @downloads << download
  end

  def <<(download)
    unless download && download.is_a?(Hash) && download[:url]
      raise 'Specify what you want to download as { url: \'http://location\' }'
    end

    @downloads << download
  end

  private

  def extract_file_and_path(url)
    file = File.basename(URI.parse(url).path)
    return file, Pathname.new(@directory) + file
  end

  def verify_md5(md5, path)
    if !md5.nil?  && md5 != Digest::MD5::file(path).hexdigest
      raise "File #{path} did not finish downloading correctly"
      print "Verified md5: #{md5}\n"
    end
  end
end
