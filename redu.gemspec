# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "redu/version"

Gem::Specification.new do |s|
  s.name        = "redu"
  s.version     = Redu::VERSION
  s.platform    = Gem::Platform::RUBY
  s.authors     = ["Curtis Spencer"]
  s.email       = ["curtis@sevenforge.com"]
  s.homepage    = ""
  s.summary     = %q{Redu is way to find where your memory is being spent in Redis}
  s.description = %q{Use Redu to find culprits and bad memory usage in your Redis installation}

  s.rubyforge_project = "redu"
  #s.add_dependency 'system_timer'
  s.add_dependency 'progressbar'
  s.add_dependency 'algorithms'
  s.add_dependency "redis",">= 2.2.2"
  s.add_dependency "thor",">= 0.14.6"
  s.add_dependency "terminal-table"

  s.add_development_dependency "bundler", ">= 1.0.0"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]
end
