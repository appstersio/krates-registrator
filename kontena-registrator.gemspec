lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'kontena/registrator'

Gem::Specification.new do |s|
  s.name          = 'kontena-registrator'
  s.version       = Kontena::Registrator::VERSION
  s.summary       = "Kontena Registrator"
  s.authors       = [
    "Tero Marttila",
  ]
  s.email         = [
    "tero.marttila@kontena.io",
  ]
  s.description   = ""

  s.executables   = ['kontena-registrator']
  s.require_paths = ["lib"]
end
