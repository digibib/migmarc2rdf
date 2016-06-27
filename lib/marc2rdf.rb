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
  def initialize (mapping)
    begin
      @mapping = mapping
    rescue JSON::ParserError => e
      throw new Error ("Error parsing mapping: #{e}")
    end
    @vocabs = {
      "duo" => "http://data.deichman.no/duo#",
      "bibo"  => "http://purl.org/ontology/bibo/",
      "ontology" => "http://placeholder.com/ontology#",
      "raw" => "http://placeholder.com/raw#",
      "placeholder" => "http://placeholder.com/",
      "lvont" => "http://lexvo.org/ontology#",
      "itemsubfield" => "http://placeholder.com/itemSubfieldCode/",
      "role" => "http://data.deichman.no/role#",
      "migration" => "http://migration.deichman.no/"
    }
    Vocabulary.import(@vocabs)
  end

  def convert(record)
    modeler = RDFModeler.new(record, {:mapping => @mapping})
    modeler.set_type(RDF::ONTOLOGY.Publication)
    modeler.convert
    RDF::Graph.new.insert(*modeler.statements)
  end
end
