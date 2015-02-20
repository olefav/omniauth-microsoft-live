# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require 'omniauth-microsoft-live/version'

Gem::Specification.new do |s|
  s.name        = "omniauth-microsoft-live"
  s.version     = OmniAuth::MicrosoftLive::VERSION
  s.authors     = ["Olefav"]
  s.email       = ["ao@anahoret.com"]
  s.homepage    = ""
  s.summary     = 'Windows Live hybrid signin strategy for OmniAuth'

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  s.add_dependency 'omniauth-oauth2', '~> 1.0'
  s.add_dependency 'multi_json', '>= 1.0.3'
  s.add_development_dependency 'rspec', '~> 2.7'
  s.add_development_dependency 'rack-test'
  s.add_development_dependency 'webmock'
end
