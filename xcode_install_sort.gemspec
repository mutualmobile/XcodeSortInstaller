# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'xcode_install_sort/version'

Gem::Specification.new do |spec|
  spec.name          = "xcode_install_sort"
  spec.version       = XcodeInstallSort::VERSION
  spec.authors       = ["Lars Anderson"]
  spec.email         = ["lars.anderson@mutualmobile.com"]
  spec.description   = "Sort-script installer for Xcode project targets"
  spec.summary       = "Installs a sort script on project file targets that sorts a project file when it is modified"
  spec.homepage      = ""
  spec.license       = "MIT"

  # spec.extensions    = "ext/xcodeproj/extconf.rb"
  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.3"
  spec.add_development_dependency "rake"
  spec.add_runtime_dependency 'xcodeproj'
  spec.add_runtime_dependency 'colored'
end
