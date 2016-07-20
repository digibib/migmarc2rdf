# Struct for RDFModeler
require 'digest'
require 'rdf/ntriples'
require 'active_support/core_ext/string'

class RDFModeler
  attr_accessor :record, :id, :uri, :map, :statements, :rdf

  ## Instance Methods
  def initialize(record, params={})
    # lookup library by id unless given as param
    @host = params[:host] || "placeholder.com"
    @record  = record
    @id      = @record['001'].value.to_i
    @uri     = RDF::URI("http://#{@host}/publication/p" + "#{Digest::MD5.hexdigest(@id.to_s)}")
    # mapping is passed as param
    @map = params[:mapping]
    return nil unless @map # you DO need a mapping
    @statements = []
  end

  # allow array or comma-separated list of types
  def set_type(types)
    Array(types).each do | type |
      @statements << RDF::Statement.new(@uri, RDF.type, type)
    end
  end

  def generate_uri(s, prefix=nil)
    begin
      uri = URI.parse("#{prefix}#{s}")
      # need to be strict on URIs - scheme and host are mandatory
      if uri.scheme && uri.host
        u = RDF::URI(uri)
      else
        u = RDF::Literal(uri)
      end
    rescue
      u = RDF::Literal("#{prefix}#{s}")
    end
  end

  def generate_objects(o, options={})
=begin
 function to split and clean object(s) by optional parameters fed from yaml file
 options are:
   :marcfield => full marcfield object to use e.g. in :combine
   :regex_split => regex split condition, eg. ", *" - split by comma and space
   :regex_match => regex match condition, eg. "(\d)+\-" - take number(s) before dash
   :urlize => non-ascii character replacement, alternatively with :downcase, :convert_chars and :regex
   :md5 => hash string with md5
   :lowercase => true or false
   :downcase => true or false (default)
   :convert_spaces => default '_'
   :regexp => default /[^-_A-Za-z0-9]/
   :regex_strip => regex match to strip away
   :regex_substitute => hash of 'orig', 'subs', and 'default' to map object substitutions - read into 'regex_subs'
   :substr_offset => string slice by position, eg. - substr_offset: 34 - get string from position 34
   :substr_length => string slice length
   :combine => combine field with one or more others
   :combinestring => string to combine field with
   regex_split takes precedence, then urlize and finally regex_strip to remove disallowed characters
=end

    regex_subs = options[:regex_substitute] || nil
    options.delete_if {|k,v| v.nil?} # remove empty options

    generated_objects = []

    # First generating of objects in following priority
    # 1) get substring on offset+length if set
    # 2) regex split on string
    # 3) take whole string
    # substring must be used on whole marcfield
    if options.has_key?(:substr_offset)
      # ignore if substr moves beyond length of string
      if o.length >= options[:substr_offset] + options[:substr_length]
        generated_objects << o.slice(options[:substr_offset],options[:substr_length])
        generated_objects.delete_if {|a| a.nil? } # needed to avoid nil-errors on invalid 008 tags
        generated_objects.delete_if {|a| a.strip.empty? }
      end
    elsif options.has_key?(:regex_split)
      res = o.split(/#{options[:regex_split]}/).flatten
      res.each {|r| generated_objects << r unless r.empty? }
    elsif options.has_key?(:regex_match)
      res = o.scan(/#{options[:regex_match]}/).flatten
      res.each {|r| generated_objects << r unless r.empty? }
    else
      generated_objects << o
    end

    if options.has_key?(:regex_substitute) and not generated_objects.empty?
      generated_objects.collect! do |obj|
        obj = obj.gsub(/[\W]+/, '').downcase
        obj.scan(/#{regex_subs['orig']}/) do |match|
          if match then obj = regex_subs['subs'][match] else obj = regex_subs['default'] end
        end
      obj # needed to make sure obj is returned, not match
      end
    end

    if options.has_key?(:combine) and not generated_objects.empty?
      generated_objects.collect! do | obj |
        obj2 = []
        options[:combine].each do |combine|
          options[:marcfield].each do |mrc|
            obj2 << mrc.value if combine == mrc.code
          end
        end
        obj2.delete_if {|d| d.nil? }
        obj = obj2.join(options[:combinestring])
      end
    end

    # Ensure we only have valid objects
    generated_objects.delete_if { |obj| obj.nil? }
    generated_objects.delete_if { |obj| obj.empty? }

    if options.has_key?(:regex_strip) and not generated_objects.empty?
      generated_objects.collect! { |obj| obj.gsub(/#{options[:regex_strip]}/, '') }
    end

    if options.has_key?(:urlize) and not generated_objects.empty?
      downcase       = true unless options[:no_downcase]
      convert_spaces = true unless options[:no_convert_spaces]
      regexp         = options[:regexp] || /[^-_A-Za-z0-9]/

      generated_objects.collect! do |obj|
        obj.urlize({:downcase => downcase, :convert_spaces => convert_spaces, :regexp => regexp})
      end
    end

    if options.has_key?(:md5) and not generated_objects.empty?
      generated_objects.collect! do |obj|
        Digest::MD5.hexdigest(obj)
      end
    end

    if options.has_key?(:lowercase) and not generated_objects.empty?
      generated_objects.collect! do |obj|
        obj.mb_chars.downcase.to_s
      end
    end


    #puts generated_objects if $debug
    return generated_objects
  end

  def assert(p=nil, o=nil)
    if p && o
      @statements << RDF::Statement.new(@uri, RDF.module_eval("#{p}"), o) unless p.empty?
    end
  end

  def relate(s=nil, p=nil, o=nil)
    if s && p && o
      @statements << RDF::Statement.new(RDF::URI(s), p, o)
    end
  end

  def convert
    # start graph handle, one graph per record, else graph will grow too large to parse
    @record.tags.each do | marctag |
      # put all record marc tag fields into array object 'marcfields' for later use
      marcfields = @record.find_all { |field| field.tag == marctag }
      # start matching MARC tags against tags from mapping, put results in match array
      match = @map["tags"].select { |m| m[marctag] }
      match.each do |mapping|
      # iterate each marc tag array object to catch multiple marc fields
        marcfields.each do | marcfield |
          # controlfields 001-009 don't have subfields
          unless mapping[marctag].has_key?('subfields')
            ################
            # Control fields
            ################
            marc_object = "#{marcfield.value}"
            unless marc_object.strip.empty?
              mapping.each do | _,values |
                values.each do | _,value |
                  objects = generate_objects(marc_object, :marcfield => marcfield, :regex_split => value['object']['regex_split'],
                    :regex_match => value['object']['regex_match'], :urlize => value['object']['urlize'], :regex_strip => value['object']['regex_strip'],
                    :regex_substitute => value['object']['regex_substitute'], :substr_offset => value['object']['substr_offset'],
                    :substr_length => value['object']['substr_length'], :combine => value['object']['combine'],
                    :combinestring => value['object']['combinestring'], :downcase => value['object']['downcase'])
                  unless objects.empty?
                    objects.each do | o |
                      unless o.strip.empty?
                        unless value['object']['datatype'] == "literal"
                          object_uri = generate_uri(o, "#{value['object']['prefix']}")
                          # first create assertion triple
                          assert("#{value['predicate']}", object_uri)
                          #assert(value['predicate'], object_uri)
                          if value.has_key?('relation')
                            ## create relation class
                            relatorclass = "#{value['relation']['class']}"
                            relate(object_uri, RDF.type, RDF.module_eval("#{relatorclass}"))
                          end # end if relation
                        else # literal
                          assert(value['predicate'], RDF::Literal("#{o}"))
                        end # end unless literal
                      end # end unless.strip.empty?
                    end # end objects.each
                  end # end unless objects.empty?
                end # end mapping.each
              end # end unless object.empty?
            end # end values.each

          else # we have subfields, iterate as regex matches
            mapping[marctag]['subfields'].each do | subfields |
              ####
              # here comes mapping of MARC datafields, subfield by subfield
              # subfields[0] contains subfield key
              # subfields[1] contains hash of rdf mapping values from mapping file
              ## CONDITIONS: creates predicate from hash array of "match" => "replacement"
              ## mandatory: put predicate in @predicate variable for later use
              ####
              subfields.each do | subfield |
                if subfield[1].has_key?('conditions')
                  @predicate = ''
                  ### condition by subfield                    ###
                  ### if no match from given array, use default ###
                  if subfield[1]['conditions'].has_key?('subfield')
                    subfield[1]['conditions']['subfield'].each do | key,value |
                      m = "#{marcfield[key]}"
                      unless m.empty?
                        predicate = m.gsub(/[\.\-]+/, '').downcase
                        predicate.scan(/#{value['orig']}/) do |match|
                          @predicate = value['subs'][match]
                          unless defined?(@predicate)
                            raise "#{match} missing from orig in mapping for tag #{marctag}"
                          end
                        end
                        if @predicate.empty? then @predicate = value['default'] end
                      else
                        @predicate = value['default']
                      end
                    end
                  ### condition by indicators                   ###
                  ### if no match from given array, use default ###
                  elsif subfield[1]['conditions'].has_key?('indicator')
                    if subfield[1]['conditions']['indicator']['indicator1']
                      marcfield.indicator1.scan(/#{subfield[1]['conditions']['indicator']['indicator1']['orig']}/) do |match|
                        @predicate = subfield[1]['conditions']['indicator']['indicator1']['subs'][match]
                      end
                    end
                    if subfield[1]['conditions']['indicator']['indicator2']
                      marcfield.indicator2.scan(/#{subfield[1]['conditions']['indicator']['indicator2']['orig']}/) do |match|
                        @predicate = subfield[1]['conditions']['indicator']['indicator2']['subs'][match]
                      end
                    end
                    if @predicate.empty? then @predicate = subfield[1]['conditions']['indicator']['default'] end
                  end
                else
                  @predicate = subfield[1]['predicate']
                end
                ####
                ## RELATIONS: make class and create relations from subfield
                ####
                if subfield[1].has_key?('relation')
                  # parse single subfield from yaml
                  if subfield[0]
                    marcfield.subfields.each_with_index do |marc_object,marc_object_index|
                      if marc_object.code == subfield[0]

                        unless marc_object.value.empty?
                          objects = generate_objects(marc_object.value, :marcfield => marcfield, :regex_split => subfield[1]['object']['regex_split'],
                            :regex_match => subfield[1]['object']['regex_match'], :urlize => subfield[1]['object']['urlize'],
                            :regex_strip => subfield[1]['object']['regex_strip'], :regex_substitute => subfield[1]['object']['regex_substitute'],
                            :substr_offset => subfield[1]['object']['substr_offset'], :substr_length => subfield[1]['object']['substr_length'],
                            :combine => subfield[1]['object']['combine'], :combinestring => subfield[1]['object']['combinestring'],
                            :downcase => subfield[1]['object']['downcase'],
                            :md5 => subfield[1]['object']['md5'],
                            :lowercase => subfield[1]['object']['lowercase'])

                          objects.each do | o, object |
                            object_uri = generate_uri(o, "#{subfield[1]['object']['prefix']}")
                            # first create assertion triple
                            assert(@predicate, object_uri)

                            ## create relation class
                            relatorclass = "#{subfield[1]['relation']['class']}"
                            relate(object_uri, RDF.type, RDF.module_eval("#{relatorclass}"))

                            # do relations have subfields? parse them too ...
                            relationsubfields = subfield[1]['relation']['subfields']
                            if relationsubfields
                              relationsubfields.each do | relsub |
                                relsub.keys.each do | relkey |

                                  # If related subfield matches original, select only subfields where index matches index of marc subtag
                                  if relkey == subfield[0]
                                    rel_marc_objects = [marcfield.subfields[marc_object_index].value]
                                  else # select all matching
                                    rel_marc_objects = marcfield.subfields.select {|sub| sub.code == relkey }.map {|o| o.value}
                                  end

                                  rel_marc_objects.each do |rel_marc_object|

                                    unless "#{rel_marc_object}".empty?
                                      relobjects = generate_objects(rel_marc_object, :marcfield => marcfield, :regex_split => relsub[relkey]['object']['regex_split'],
                                        :regex_match => relsub[relkey]['object']['regex_match'], :urlize => relsub[relkey]['object']['urlize'],
                                        :regex_strip => relsub[relkey]['object']['regex_strip'], :regex_substitute => relsub[relkey]['object']['regex_substitute'],
                                        :substr_offset => relsub[relkey]['object']['substr_offset'], :substr_length => relsub[relkey]['object']['substr_length'],
                                        :combine => relsub[relkey]['object']['combine'], :combinestring => relsub[relkey]['object']['combinestring'],
                                        :md5 => relsub[relkey]['object']['md5'], :lowercase => relsub[relkey]['object']['lowercase'], :downcase => relsub[relkey]['object']['downcase'])
                                      relobjects.each do | ro |
                                        if subfield[0] == relkey
                                          relate(object_uri, RDF.module_eval("#{relsub[relkey]['predicate']}"), RDF::Literal("#{ro}", :language => relsub[relkey]['object']['lang']))
                                        else
                                          if relsub[relkey]['object']['datatype'] == "uri"
                                            relobject_uri = generate_uri(ro, "#{relsub[relkey]['object']['prefix']}")

                                            relate(object_uri, RDF.module_eval("#{relsub[relkey]['predicate']}"), RDF::URI(relobject_uri))
                                          else
                                            relate(object_uri, RDF.module_eval("#{relsub[relkey]['predicate']}"), RDF::Literal("#{ro}", :language => relsub[relkey]['object']['lang']))
                                          end
                                        end
                                      end # relobjects.each
                                    end # end unless empty rel_marc_object
                                  end # rel_marc_objects.each
                                end # end relsub keys each
                              end # end relationsubfields.each
                            end # end if relationsubfields
                          end # objects.each
                        end # end unless object.empty?
                      end # if marc_object.code == subfield[0]
                    end # end marc_objects_each
                  end

                else # no relations parse straight triples

                  if subfield[0]
                    marc_objects = marcfield.subfields.select {|sub| sub.code == subfield[0] }.map {|o| o.value}
                    marc_objects.each do |marc_object|
                      unless "#{marc_object}".empty?
                        objects = generate_objects("#{marc_object}", :marcfield => marcfield, :regex_split => subfield[1]['object']['regex_split'],
                          :regex_match => subfield[1]['object']['regex_match'], :urlize => subfield[1]['object']['urlize'],
                          :regex_strip => subfield[1]['object']['regex_strip'], :regex_substitute => subfield[1]['object']['regex_substitute'],
                          :substr_offset => subfield[1]['object']['substr_offset'], :substr_length => subfield[1]['object']['substr_length'],
                          :combine => subfield[1]['object']['combine'], :combinestring => subfield[1]['object']['combinestring'],
                          :downcase => subfield[1]['object']['downcase'],
                          :md5 => subfield[1]['object']['md5'],
                          :lowercase => subfield[1]['object']['lowercase'])
                        objects.each do | o |
                          case subfield[1]['object']['datatype']
                          when "uri"
                            object_uri = generate_uri(o, "#{subfield[1]['object']['prefix']}")
                            assert(@predicate, object_uri)
                          when "integer"
                            assert(@predicate, RDF::Literal("#{o}", :datatype => RDF::XSD.integer))
                          when "float"
                            assert(@predicate, RDF::Literal("#{o}", :datatype => RDF::XSD.float))
                          when "gYear"
                            assert(@predicate, RDF::Literal("#{o}", :datatype => RDF::XSD.gYear))
                          else # literal
                            assert(@predicate, RDF::Literal("#{o}", :language => subfield[1]['object']['lang']))
                          end # end if subfield
                        end # end objects.each do | o |
                      end # end unless object.empty?
                    end # end marc_objects each
                  end
                end # end subfields.each
              end
            end
          end # end unless mappingvalue['subfield']
        end # end marcfields.each
      end # end match.each
    end # end record.tags.each
  end

end
