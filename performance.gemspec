lib = File.expand_path('../lib', __FILE__)

$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

Gem::Specification.new do |spec|
  spec.name             = "gocd-performance"
  spec.version          = "0.1"
  spec.authors          = ["GoCD"]
  spec.email            = ["gocd-dev@googlegroups.com"]
  spec.summary          = %q{GoCD performance scripts}
  spec.description      = %q{GoCD performance scripts}
  spec.homepage         = "http://github.com/gocd/performance"
  spec.license          = "Apache"

  spec.files            = ['lib/**.rb']
  spec.test_files       = ['tests/*.rb']
  spec.require_paths    = ['lib']
end
