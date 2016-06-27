#!/usr/bin/env ruby

require "rdf"

class Vocabulary

  def self.import(vocabs)
    return nil unless vocabs.is_a?(Hash)
    vocabs.each do |prefix,uri|
      set(prefix,uri)
    end
  end

  # defines RDF Vocabularies
  def self.set(prefix, uri)
    const = prefix.upcase.to_sym
    RDF.send(:const_set, prefix.upcase, RDF::Vocabulary.new("#{uri}")) unless RDF.const_defined?(const)
  end

  # undefines RDF Vocabulary
  def unset
    const = prefix.upcase.to_sym
    RDF.send(:remove_const, const) if RDF.const_defined?(const)
  end

end