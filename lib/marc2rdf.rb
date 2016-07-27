#!/usr/bin/env ruby

require 'rubygems'
require 'bundler/setup'
require 'rdf'
require 'marc'
require 'json'

require_relative './rdfmodeler.rb'
require_relative './vocabulary.rb'
require_relative './string.rb'

class Marc2RDF
  attr_accessor :graphs
  def initialize (mapping, host="placeholder.com")
    @host = host
    begin
      @mapping = mapping
    rescue JSON::ParserError => e
      throw new Error ("Error parsing mapping: #{e}")
    end
    @vocabs = {
      "duo" => "http://data.deichman.no/duo#",
      "bibo"  => "http://purl.org/ontology/bibo/",
      "ontology" => "http://#{@host}/ontology#",
      "raw" => "http://data.deichman.no/raw#",
      "lvont" => "http://lexvo.org/ontology#",
      "role" => "http://data.deichman.no/role#",
      "migration" => "http://migration.deichman.no/"
    }
    Vocabulary.import(@vocabs)
  end

  def convert(record)
    modeler = RDFModeler.new(record, {:mapping => @mapping, :host => @host})
    modeler.set_type(RDF::ONTOLOGY.Publication)
    modeler.convert
    RDF::Graph.new.insert(*modeler.statements)
  end
end
