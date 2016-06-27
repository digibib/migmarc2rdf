#!/usr/bin/env ruby

require 'yaml'
require_relative './lib/marc2rdf.rb'

def usage(s)
    $stderr.puts(s)
    $stderr.puts("Usage: \n")
    $stderr.puts("#{File.basename($0)} -m mapping_file -i input_file\n")
    $stderr.puts("  -m mapping file (default config/mapping.yaml)\n")
    $stderr.puts("  -i input_file \(marcxml db\)\n")
    exit(2)
end

loop { case ARGV[0]
    when '-m' then  ARGV.shift; $mapping_file = ARGV.shift
    when '-i' then  ARGV.shift; $input_file  = ARGV.shift
    when /^-/ then  usage("Unknown option: #{ARGV[0].inspect}")
    else
        if $input_file.nil? then usage("Missing argument!\n") end
    break
end; }

mapping_file = $mapping_file ? $mapping_file : 'config/mapping.yaml'
mapping = YAML.load(IO.read(mapping_file))

start = Time.now

marc2rdf = Marc2RDF.new(mapping)
marc_reader = MARC::XMLReader.new($input_file)
for record in marc_reader
    STDOUT.puts marc2rdf.convert(record).dump(:ntriples)
end

diff = Time.now - start
STDERR.puts("MARC2RDF conversion done in #{diff} seconds")
