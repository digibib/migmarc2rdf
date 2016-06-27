require 'rubygems'
require 'bundler/setup'
require 'rdf/spec'
require 'rdf'
require 'rack/test'
require 'webmock/rspec'

ENV['RACK_ENV'] = 'test'

if ENV['COVERAGE']
  require 'simplecov'
  SimpleCov.start do
    add_filter '/spec'
  end
end

# code init
require File.join(File.dirname(__FILE__), '..', 'lib', 'marc2rdf.rb')
# Vocabularies used in spec tests
Vocabulary.import({
	"ontology" => "http://placeholder.com/ontology#",
	"raw" => "http://placeholder.com/raw#",
	"migration" => "http://placeholder.com/migration#"
	})

RSpec.configure do |config|
  config.include Rack::Test::Methods
  config.mock_with :rspec
  config.expect_with :rspec
end
