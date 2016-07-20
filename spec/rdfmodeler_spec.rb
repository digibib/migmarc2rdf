# RDFModeler takes json mapping and marc xml, outputs RDF
require File.join(File.dirname(__FILE__), 'spec_helper')
mapping = YAML.load(IO.read(File.join(File.dirname(__FILE__), '..', 'config', 'mapping.yaml')))
input_file = File.join(File.dirname(__FILE__), 'marcrecord.xml')
output = IO.read(File.join(File.dirname(__FILE__), 'marcrecord.ntriples'))
describe Marc2RDF do
  context "full conversion with input file and mapping" do
    it "ntriples in output should match mapped values" do
      marc2rdf = Marc2RDF.new(mapping)
      record = MARC::XMLReader.new(input_file).first
      expect(marc2rdf.convert(record).dump(:ntriples)).to eq(output)
    end
  end
end
describe RDFModeler do
  context "generating RDF objects" do
    before(:each) do
      @reader = MARC::XMLReader.new(input_file)
      @modeler = RDFModeler.new(@reader.first, {:mapping => mapping})
      @str = "abcdef"
    end
    it "should create an RDF type" do
      @modeler.set_type(RDF::BIBO.Book)
      expect(@modeler.statements[0].to_s).to include("<http://purl.org/ontology/bibo/Book>")
    end
    it "should support substring offset and substring length" do
      obj = @modeler.generate_objects(@str, {:substr_offset => 2, :substr_length => 4})
      expect(obj.first).to eq("cdef")
    end
    it "should return empty object when :substr_length and :substr_offset exceeds length of string" do
      obj = @modeler.generate_objects(@str, {:substr_offset => 11, :substr_length => 1})
      expect(obj).to be_empty
    end
    it "generated URIs should be of type RDF::URI" do
      uri = @modeler.generate_uri(@str, "http://example.com/")
      expect(uri).to be_a(RDF::URI)
    end
    it "trying to generate URI object with invalid characters should result in RDF::Literal" do
      uri = @modeler.generate_uri(@str, "http:||example.com")
      expect(uri).to be_a(RDF::Literal)
    end
    it "trying to generate URI object with missing prefix should result in RDF::Literal" do
      uri = @modeler.generate_uri(@str, "www.example.com")
      expect(uri).to be_a(RDF::Literal)
    end
    it "should regex_split and then regex_substitute" do
      obj = @modeler.generate_objects(@str, {:regex_split => "(\\w{2})", :regex_substitute => {
          "orig" => "ab|cd|ef",
          "subs" => {"ab" => "AA", "cd" => "BB", "ef" => "CC"},
          "default" => "ZERO"
      }
      })
      expect(obj).to eq(["AA", "BB", "CC"])
    end
    it "should support regex_match against a string" do
      obj = @modeler.generate_objects("1945-1999", {
          :regex_match => "(\\d+)\-"
      })
      expect(obj.first).to eq("1945")
    end
    it "should combine subfields with chosen combinestring" do
      obj = @modeler.generate_objects(@str, {
          :marcfield => MARC::DataField.new('245', ' ', ' ', ['a', 'A Title'], ['b', 'A Subtitle']),
          :combine => ["a", "b"],
          :combinestring => " : "
      })
      expect(obj.first).to eq("A Title : A Subtitle")
    end
    it "should urlize a string, defaulting to convert spaces and downcase" do
      str = "A Simple String"
      obj = @modeler.generate_objects(str, {:urlize => true})
      expect(obj.first).to eq("a_simple_string")
    end
    it "should hash a string width md5 if requested" do
      str = "A Simple String"
      obj = @modeler.generate_objects(str, {:md5 => true})
      expect(obj.first).to eq("ce74867407f887269af5a32dbbf0b856")
    end
    it "should lowercase a string if requested" do
      str = "A Simple String"
      obj = @modeler.generate_objects(str, {:lowercase => true})
      expect(obj.first).to eq("a simple string")
    end
    it "should be able NOT to downcase and convert_spaces in urlize" do
      str = "A Simple String"
      obj = @modeler.generate_objects(str, {:urlize => true, :no_downcase => true, :no_convert_spaces => true})
      expect(obj.first).to eq("ASimpleString")
    end
    it "should urlize special characters against mapping in String module" do
      str = "\u00C6gir"
      obj = @modeler.generate_objects(str, {:urlize => true})
      expect(obj.first).to eq("aegir")
    end
    it "should urlize with custom regexp" do
      str = "abcdef"
      obj = @modeler.generate_objects(str, {:urlize => true, :regexp => /[^a-e]/})
      expect(obj.first).to eq("abcde")
    end
  end
  context "advanced RDF modelling and conversion" do
    before(:each) do
      base = 'http://placeholder.com/resource/'
      @reader = MARC::XMLReader.new(input_file)
      @record_1 = @reader.first
      @record_2 = @reader.first
      @record_3 = @reader.first
      @record_4 = @reader.first
      @record_5 = @reader.first
      @record_6 = @reader.first
      @record_7 = @reader.first
      @map = mapping
    end

    context "generating RDF statements" do

      context "repeated subfields" do

        it "generates statements from repeated subfields" do
          record = MARC::Record.new()
          record.append(MARC::ControlField.new('001', 123456))
          record.append(MARC::DataField.new('650', ' ',  ' ', ['a', 'Subject'], ['x', 'Cats'], ['x', 'Dogs']))

          map = { "tags" => [{ "650" => {
            "subfields" => [{
              "x" => {
                "predicate" => "ONTOLOGY.subject",
                "object" => {
                  "datatype" => "literal"
                }
              }
            }]
          }}]}
          r = RDFModeler.new(record, :mapping => map)
          r.convert
          expect(r.statements[0].to_s).to eq("<http://placeholder.com/publication/pe10adc3949ba59abbe56e057f20f883e> <http://placeholder.com/ontology#subject> \"Cats\" .")
          expect(r.statements[1].to_s).to eq("<http://placeholder.com/publication/pe10adc3949ba59abbe56e057f20f883e> <http://placeholder.com/ontology#subject> \"Dogs\" .")
        end

        it "when creating relation, adds only relevant subfield by using same index" do
          record = MARC::Record.new()
          record.append(MARC::ControlField.new('001', 123456))
          record.append(MARC::DataField.new('650', ' ',  ' ', ['a', 'Animals'], ['x', 'Cats'], ['x', 'Dogs']))

          map = { "tags" => [{ "650" => {
            "subfields" => [{
              "x" => {
                "predicate" => "ONTOLOGY.subject",
                "object" => {
                  "datatype" => "uri",
                  "prefix" => "http://placeholder.com/subject/",
                  "urlize" => true
                },
                "relation" => {
                  "subfields" => [
                    "a" => {
                      "predicate" => "ONTOLOGY.label",
                      "object" => {
                        "datatype" => "literal"
                      }
                    },
                    "x" => {
                      "predicate" => "ONTOLOGY.subjectLabel",
                      "object" => {
                        "datatype" => "literal"
                      }
                    }
                  ]
                }
              }
            }]
          }}]}
          r = RDFModeler.new(record, :mapping => map)
          r.convert
          expect(r.statements[0].to_s).to eq("<http://placeholder.com/publication/pe10adc3949ba59abbe56e057f20f883e> <http://placeholder.com/ontology#subject> <http://placeholder.com/subject/cats> .")
          expect(r.statements[1].to_s).to eq("<http://placeholder.com/subject/cats> <http://placeholder.com/ontology#label> \"Animals\" .")
          expect(r.statements[2].to_s).to eq("<http://placeholder.com/subject/cats> <http://placeholder.com/ontology#subjectLabel> \"Cats\" .")
          expect(r.statements[3].to_s).to eq("<http://placeholder.com/publication/pe10adc3949ba59abbe56e057f20f883e> <http://placeholder.com/ontology#subject> <http://placeholder.com/subject/dogs> .")
          expect(r.statements[4].to_s).to eq("<http://placeholder.com/subject/dogs> <http://placeholder.com/ontology#label> \"Animals\" .")
          expect(r.statements[5].to_s).to eq("<http://placeholder.com/subject/dogs> <http://placeholder.com/ontology#subjectLabel> \"Dogs\" .")
        end
      end
    end

    context "generating literals" do
      it "generates isbn, number of pages, part title, original part title, part number, edition audience and illustrative matter for first record" do
        r = RDFModeler.new(@record_1, :mapping => @map)
        r.convert
        expect(r.statements.to_s).to include("<http://placeholder.com/ontology#isbn> \"978-0-415-85745-1\"")
        expect(r.statements.to_s).to include("<http://placeholder.com/migration#numberOfPages> \"XV, 309 s.\"")
        expect(r.statements.to_s).to include("<http://placeholder.com/ontology#partTitle> \"First part\"")
        expect(r.statements.to_s).to include("<http://placeholder.com/migration#originalPartTitle> \"Original part title\"")
        expect(r.statements.to_s).to include("<http://placeholder.com/ontology#partNumber> \"1\"")
        expect(r.statements.to_s).to include("<http://placeholder.com/ontology#edition> \"2nd edition\"")
        expect(r.statements.to_s).to include("<http://placeholder.com/raw#illustrativeMatter> \"ill.\"")
      end
      it "allows a modified mapping as param" do
        @map["tags"] << { "020" => {
          "subfields" => [{
            "a" => {
              "predicate" => "BIBO.isbn",
              "object" => {
                "datatype" => "literal"
              }
            }
          }]
        }}
        r = RDFModeler.new(@record_1, :mapping => @map)
        r.convert
        expect(r.statements.to_s).to include("http://purl.org/ontology/bibo/isbn")
      end
      it "creates literals with datatype integers" do
        @map["tags"] << { "300" => {
          "subfields" => [{
            "a" => {
              "predicate" => "ONTOLOGY.pagecount",
              "object" => {
                "datatype" => "integer",
                "regex_strip" => "[\\D]+",
              }
            }
          }]
        }}
        r = RDFModeler.new(@record_1, :mapping => @map)
        r.convert
        expect(r.statements.to_s).to include("\"309\"^^<http://www.w3.org/2001/XMLSchema#integer>")
      end
      it "creates literals with datatype float" do
        @map["tags"] << { "300" => {
          "subfields" => [{
            "a" => {
              "predicate" => "ONTOLOGY.pagecount",
              "object" => {
                "datatype" => "float",
                "regex_strip" => "[\\D]+",
              }
            }
          }]
        }}
        r = RDFModeler.new(@record_1, :mapping => @map)
        r.convert
        expect(r.statements.to_s).to include("\"309\"^^<http://www.w3.org/2001/XMLSchema#float>")
      end
      it "creates part title" do
        @map["tags"] << { "245" => {
          "subfields" => [{
            "p" => {
              "predicate" => "ONTOLOGY.partTitle",
              "object" => {
                "datatype" => "string",
              }
            }
          }]
        }}
        r = RDFModeler.new(@record_1, :mapping => @map)
        r.convert
        expect(r.statements.to_s).to include("partTitle")
      end
    end

    context "generating URIs" do
      it "generates audience for first record" do
        r = RDFModeler.new(@record_1, :mapping => @map)
        r.convert
        expect(r.statements.to_s).to include("<http://placeholder.com/ontology#audience> <http://data.deichman.no/audience#adult>")
      end
      it "generates audience for second record" do
        r = RDFModeler.new(@record_2, :mapping => @map)
        r.convert
        expect(r.statements.to_s).to include("<http://placeholder.com/ontology#audience> <http://data.deichman.no/audience#juvenile>")
      end
      it "creates an audience URI from DataField 019" do
        r = RDFModeler.new(@record_3, :mapping => @map)
        r.convert
        expect(r.statements.to_s).to include("<http://placeholder.com/ontology#audience> <http://data.deichman.no/audience#ages0To2>")

        r = RDFModeler.new(@record_4, :mapping => @map)
        r.convert
        expect(r.statements.to_s).to include("<http://placeholder.com/ontology#audience> <http://data.deichman.no/audience#ages3To5>")

        r = RDFModeler.new(@record_5, :mapping => @map)
        r.convert
        expect(r.statements.to_s).to include("<http://placeholder.com/ontology#audience> <http://data.deichman.no/audience#ages6To8>")

        r = RDFModeler.new(@record_6, :mapping => @map)
        r.convert
        expect(r.statements.to_s).to include("<http://placeholder.com/ontology#audience> <http://data.deichman.no/audience#ages11To12")

        r = RDFModeler.new(@record_7, :mapping => @map)
        r.convert
        expect(r.statements.to_s).to include("<http://placeholder.com/ontology#audience> <http://data.deichman.no/audience#ages11To12>")
        expect(r.statements.to_s).to include("<http://placeholder.com/ontology#audience> <http://data.deichman.no/audience#ages13To15>")
      end
      it "creates a Class from language relation from ControlField 008" do
        r = RDFModeler.new(@record_1, :mapping => @map)
        r.convert
        expect(r.statements.to_s).to include("<http://placeholder.com/ontology#language> <http://lexvo.org/id/iso639-3/eng>")
      end
      it "creates a format URI from DataField" do
        r = RDFModeler.new(@record_1, :mapping => @map)
        r.convert
        expect(r.statements.to_s).to include("http://data.deichman.no/format#Book")
      end
      it "generates literary form for first record" do
        r = RDFModeler.new(@record_1, :mapping => @map)
        r.convert
        expect(r.statements.to_s).to include("<http://placeholder.com/ontology#literaryForm> <http://data.deichman.no/literaryForm#nonfiction>")
      end
      it "generates literary form for second record" do
        r = RDFModeler.new(@record_2, :mapping => @map)
        r.convert
        expect(r.statements.to_s).to include("<http://placeholder.com/ontology#literaryForm> <http://data.deichman.no/literaryForm#fiction>")
      end
      it "generates biography for seventh record" do
        r = RDFModeler.new(@record_7, :mapping => @map)
        r.convert
        expect(r.statements.to_s).to include("<http://placeholder.com/ontology#biography> <http://data.deichman.no/biography#autobiography>")
      end
      it "generates writing system for first record" do
        r = RDFModeler.new(@record_1, :mapping => @map)
        r.convert
        expect(r.statements.to_s).to include("<http://placeholder.com/ontology#writingSystem> <http://data.deichman.no/writingSystem#cyrillic>")
      end
      it "generates adaptation uri for first record" do
        r = RDFModeler.new(@record_1, :mapping => @map)
        r.convert
        expect(r.statements.to_s).to include("<http://placeholder.com/ontology#adaptationOfPublicationForParticularUserGroups> <http://data.deichman.no/adaptationForParticularUserGroups#largePrint>")
        expect(r.statements.to_s).to include("<http://placeholder.com/ontology#adaptationOfPublicationForParticularUserGroups> <http://data.deichman.no/adaptationForParticularUserGroups#largePrint>")
        expect(r.statements.to_s).to include("<http://placeholder.com/ontology#adaptationOfPublicationForParticularUserGroups> <http://data.deichman.no/adaptationForParticularUserGroups#braille>")
        expect(r.statements.to_s).to include("<http://placeholder.com/ontology#adaptationOfPublicationForParticularUserGroups> <http://data.deichman.no/adaptationForParticularUserGroups#signLanguage>")
        expect(r.statements.to_s).to include("<http://placeholder.com/ontology#adaptationOfPublicationForParticularUserGroups> <http://data.deichman.no/adaptationForParticularUserGroups#tactile>")
        expect(r.statements.to_s).to include("<http://placeholder.com/ontology#adaptationOfPublicationForParticularUserGroups> <http://data.deichman.no/adaptationForParticularUserGroups#capitalLetters>")
      end
      it "creates a format URI from conditions on a subfield" do
        @map["tags"] << { "700" => {
          "subfields" => [{
            "3" => {
              "object" => {
                "datatype" => "uri",
                "prefix" => "http://example.com/person/x"
              },
              "conditions" => {
                "subfield" => {
                  "e" => {
                    "default" => "DC.contributor",
                    "subs" => { "red" => "BIBO.editor" },
                    "orig" => "red"
                    }
                  }
                }
              }
            }]
          }}
        r = RDFModeler.new(@record_1, :mapping => @map)
        r.convert
        expect(r.statements.to_s).to include("http://purl.org/ontology/bibo/editor")
      end
      it "on failed conditions default should be used" do
        @map["tags"] << { "700" => {
          "subfields" => [{
            "3" => {
              "object" => {
                "datatype" => "uri",
                "prefix" => "http://example.com/person/x"
              },
              "conditions" => {
                "subfield" => {
                  "e" => {
                    "default" => "DC.contributor",
                    "subs" => { "overs" => "BIBO.translator" },
                    "orig" => "nonexistingcondition"
                    }
                  }
                }
              }
            }]
          }}
        r = RDFModeler.new(@record_1, :mapping => @map)
        r.convert
        expect(r.statements.to_s).to include("http://purl.org/dc/terms/contributor")
      end
      it "conditions against an empty or nonexisting subfield, should use default" do
        @map["tags"] << { "700" => {
          "subfields" => [{
            "3" => {
              "object" => {
                "datatype" => "uri",
                "prefix" => "http://example.com/person/x"
              },
              "conditions" => {
                "subfield" => {
                  "nonexistingsubfield" => {
                    "default" => "DC.contributor",
                    "subs" => { "ignore" => "ignore" },
                    "orig" => "nonexistingcondition"
                    }
                  }
                }
              }
            }]
          }}
        r = RDFModeler.new(@record_1, :mapping => @map)
        r.convert
        expect(r.statements.to_s).to include("http://purl.org/dc/terms/contributor")
      end
      it "chooses predicate based on conditions from indicator 1" do
        @map["tags"] << { "245" => {
          "subfields" => [{
            "a" => {
              "object" => {
                "datatype" => "literal"
              },
              "conditions" => {
                "indicator" => {
                  "default" => "ONTOLOGY.anyTitle",
                  "indicator1" => {
                    "subs" => {
                      "0" => "ONTOLOGY.firstTitle",
                      "1" => "ONTOLOGY.anyTitle"
                    },
                    "orig" => "0|1"
                  }
                }
              }
            }
          }]
        }}
        r = RDFModeler.new(@record_1, :mapping => @map)
        r.convert
        expect(r.statements.to_s).to include("http://placeholder.com/ontology#firstTitle")
      end
      it "chooses predicate based on conditions from indicator 2" do
        @map["tags"] << { "245" => {
          "subfields" => [{
            "a" => {
              "object" => {
                "datatype" => "literal"
              },
              "conditions" => {
                "indicator" => {
                  "default" => "ONTOLOGY.anyTitle",
                  "indicator2" => {
                    "subs" => {
                      "0" => "ONTOLOGY.anotherTitle",
                      "1" => "ONTOLOGY.anyTitle"
                    },
                    "orig" => "0|1"
                  }
                }
              }
            }
          }]
        }}
        r = RDFModeler.new(@record_1, :mapping => @map)
        r.convert
        expect(r.statements.to_s).to include("http://placeholder.com/ontology#anotherTitle")
      end
    end
  end
end
