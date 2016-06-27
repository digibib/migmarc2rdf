#!/usr/bin/env ruby

require 'yaml'
require_relative './lib/marc2rdf.rb'

def usage(s)
    $stderr.puts(s)
    $stderr.puts("Usage: \n")
    $stderr.puts("#{File.basename($0)} -m mapping [ -i input_file || -d input_dir ] [-o output_file]\n")
    $stderr.puts("  -m mapping file (yaml)\n")
    $stderr.puts("  -i input_file \(marcxml\)\n")
    $stderr.puts("  -d input_dir (load all .marcxml files in dir)\n")
    $stderr.puts("  -o output_dir")
    exit(2)
end

loop { case ARGV[0]
    when '-m' then  ARGV.shift; $mapping_file = ARGV.shift
    when '-i' then  ARGV.shift; $input_file  = ARGV.shift
    when '-d' then  ARGV.shift; $input_dir  = ARGV.shift
    when '-o' then  ARGV.shift; $output_dir = ARGV.shift
    when /^-/ then  usage("Unknown option: #{ARGV[0].inspect}")
    else
        if $input_file.nil? && $input_dir.nil? then usage("Missing argument!\n") end
        if $input_file && $input_dir then usage("Please only one of -i or -d !\n") end
    break
end; }

mapping_file = $mapping_file ? $mapping_file : 'mapping.yaml'
mapping = YAML.load(IO.read(mapping_file))

start = Time.now

if $input_dir
    files = Dir.glob($input_dir+"/*.marcxml")
    files.each do |file|
        rdf = Marc2RDF.new(mapping, file)
        if $output_dir
            dir = File.join(File.dirname(__FILE__), $output_dir)
            Dir.mkdir(dir) unless File.exists?(dir)
            rdf.graphs.each do | graph |
                File.open(File.join(dir, "#{graph[:id]}.nt"), 'w') do |f|
                    f.write(graph[:data].dump(:ntriples))
                end
            end
        else
            # just dump raw ntriples
            STDOUT.puts rdf.dump_all_graphs
        end
    end
else
  rdf = Marc2RDF.new(mapping, $input_file)
  if $output_dir
    dir = File.join(File.dirname(__FILE__), $output_dir)
    Dir.mkdir(dir) unless File.exists?(dir)
    go! do
        File.open(File.join(dir, "#{graph[:id]}.nt"), 'a+') do |f|
            f.write(graph[:data].dump(:ntriples))
        end
    end
  else
    # just dump raw ntriples
    STDOUT.puts rdf.dump_all_graphs
  end
end

diff = Time.now - start
STDERR.puts("MARC2RDF conversion done in #{diff} seconds")
