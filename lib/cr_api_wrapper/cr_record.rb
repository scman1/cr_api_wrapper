#lib/cordra_rest_cliet/cr_record.rb
require 'serrano'
require 'faraday'
require 'json'

module CrApiWrapper
  class CrRecord
    # cr record attributes
    attr_reader :id, :type, :content, :metadata
    # retrieves an object by ID

    # use content negotiation to get publication
    # doi: id of the publication to retrieve
    def self.find(doi)
      record_obj = JSON.parse(Serrano.content_negotiation(ids: doi, format: "citeproc-json"))
      return record_obj #returns a hash containing the record
    end

    def self.random(sample_size)
      doi_list = Serrano.random_dois(sample: sample_size)
      return doi_list
    end

  end
  #create objects dinamically
  class CrObjectFactory
    def self.create_class(new_class, *fields)
      c = Class.new do
        fields.flatten.each do |field|
          #replace backslashes and space in names with underscores
          field = field.gsub('/','_')
          field = field.gsub(' ','_')
          field = field.gsub('-','_')
          define_method field.intern do
            instance_variable_get("@#{field}")
          end
          define_method "#{field}=".intern do |arg|
            instance_variable_set("@#{field}", arg)
          end
        end
      end
      CrApiWrapper.const_set new_class, c
      return c
    end

    def self.assing_attributes(instance, values)
      values.each do |field, arg|
        #replace backslashes and space in names with underscores
        field = field.gsub('/','_')
        field = field.gsub(' ','_')
        field = field.gsub('-','_')
        instance.instance_variable_set("@#{field}", arg)
      end
    end
  end
end
