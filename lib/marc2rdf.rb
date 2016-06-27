#!/usr/bin/env ruby

require 'rubygems'
require 'bundler/setup'
require 'rdf'
require 'marc'
require 'json'
require 'pry' if ENV['RACK_ENV'] = 'test'

require_relative './rdfmodeler.rb'
require_relative './vocabulary.rb'
require_relative './string.rb'

class Marc2RDF
  attr_accessor :graphs, :reader
  def initialize (mapping, input_file)
    @graphs = []
    begin
      @mapping = mapping
    rescue JSON::ParserError => e
      throw new Error ("Error parsing mapping: #{e}")
    end
    @reader = MARC::XMLReader.new(input_file)
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
    convert
  end

  def convert
    i = 0
    @reader.each do | record |
      i += 1
      if $recordlimit then break if i > $recordlimit end
      modeler = RDFModeler.new(record, {:mapping => @mapping})
      modeler.set_type(RDF::ONTOLOGY.Publication)
      modeler.convert
      @graphs << {:id => modeler.id, :data => RDF::Graph.new.insert(*modeler.statements) }
    end

  end # end record loop

  def dump_ntriples(graph)
    graph.dump(:ntriples)
  end

  def dump_all_graphs(format = :ntriples)
    buf = ''
    @graphs.each {|graph| buf += graph[:data].dump(format) }
    buf
  end
end
