# CSV gem for handling csv data
require 'csv'
# JSON gem for handling json data
require 'json'
# validator from schema
require 'json_schemer'
# file manager
require 'pathname'


# Run the gem on a random sample of publications from crossref
require './lib/cr_api_wrapper'

# from code found on:
# https://stackoverflow.com/questions/5622435/how-do-i-convert-a-ruby-class-name-to-a-underscore-delimited-symbol
# by:
# https://stackoverflow.com/users/312586/kikito
def underscore(a_word)
  u_word = a_word.dup
  u_word.gsub!(/::/, '/')
  u_word.gsub!(/([A-Z]+)([A-Z][a-z])/,'\1_\2')
  u_word.gsub!(/([a-z\d])([A-Z])/,'\1_\2')
  u_word.tr!("-", "_")
  u_word.downcase!
  u_word
end

# from code found on:
# https://stackoverflow.com/questions/9524457/converting-string-from-snake-case-to-camelcase-in-ruby/9524521
# by:
# https://stackoverflow.com/users/3869936/user3869936
def camelise(a_word)
  return a_word.split('_').collect(&:capitalize).join
end

def get_cr_pub_data(doi_text)
  # A. get record data
  crr = CrApiWrapper::CrRecord.find(doi_text)
  return crr
end

def build_cr_record_object(cr_json_object, object_class)
  # B. build new class using schema
  cro_properties = cr_json_object.keys
  cra_keys = nil
  cro_class = nil
  cro_properties.each do |instance_var|
    if cra_keys == nil or !cra_keys.include?(instance_var)
      cro_class = CrApiWrapper::CrObjectFactory.create_class object_class, cro_properties
      cra_keys = cro_properties
      break
    end
  end
  #cro_class = CrApiWrapper::CrObjectFactory.create_class object_class, cro_properties
  new_cro = cro_class.new
  # C. assing object values in content to class instance
  CrApiWrapper::CrObjectFactory.assing_attributes new_cro, cr_json_object
  # now handle nested objects
  cro_properties.each do |field|
    instance_var = field.gsub('/','_').downcase()
    instance_var.gsub!(' ','_')
    instance_var = instance_var.gsub('-','_')
    field_value = new_cro.instance_variable_get("@#{instance_var}")
    field_type = field_value.class
    #puts "Field: " + instance_var + " Type: "  + field_type.to_s + " Value: " + field_value.to_s
    if field_type == Hash
      # a hash is the representation of a nested object
      # handle this as a hash
      new_class_name = "Cr" + camelise(instance_var)
      #puts "handle this as a Hash create class " + new_class_name
      cr_nested_object = build_cr_record_object(field_value, new_class_name)
      #puts cr_nested_object
      #puts "***************************************************************"
      new_cro.instance_variable_set("@#{instance_var}", cr_nested_object)
    elsif field_type == Array
      values_list = []
      # an array can contain many objects
      # treat each array elemen as a nested object
      #puts "***************************************************************"
      #puts "handle this as an Array"
      #puts field_value[0]
      #puts "***************************************************************"
      field_value.each do |fvs|
        cr_list_object = nil
        if fvs.class == Hash
          new_class_name = "Cr" + camelise(instance_var)
          cr_list_object = build_cr_record_object(fvs, new_class_name)
        else
          cr_list_object = fvs
        end
        values_list.append(cr_list_object)
      end
      new_cro.instance_variable_set("@#{instance_var}", values_list)
    end
  end
  return new_cro
end

# verify returned files against schema
def verify_with_schema(test_file)
  schema_file = './json_schema/cr_metadata_api_format_corrected.json'
  schema = Pathname.new(schema_file)
  schemer = JSONSchemer.schema(schema)
  json_file = nil
  File.open(test_file,"r") do |f|
    json_file = JSON.parse(f.read)
  end
  if schemer.valid?(json_file)
    puts test_file + " matches " + schema_file
    return true
  else
    puts "** "+test_file + " does not match " + schema_file
    return false
  end
end

# get a json object and save it locally if not recovered yet.
def get_cr_json_object(cr_doi)
  crr = nil
  doi_file = './json_files/' + cr_doi.gsub('/','_').downcase() + '.json'
  if !File.exists?(doi_file)
    crr = CrApiWrapper::CrRecord.find(cr_doi)
    File.open(doi_file,"w") do |f|
      f.write(JSON.pretty_generate(crr))
    end
  else
    File.open(doi_file,"r") do |f|
      crr = JSON.parse(f.read)
    end
  end
  # verify that the recoverd object matches the schema
  if verify_with_schema(doi_file)
    return crr
  else
    return nil
  end
end

# read a list of objects and create an object schema which is common to all
# use json_schema generator to build the schemas
# use json_schema validator to verify if they all match

doi_list = CSV.read("doi_list.csv", headers: true)
puts doi_list.by_col[0]
doi_list = doi_list.by_col[0]

doi_list.each do |cr_doi|
  crr = get_cr_json_object(cr_doi)
  if crr != nil
    puts "DOI: " + crr['DOI'].to_s + " Title: " + crr['title'].to_s  + " **References: " + crr['is-referenced-by-count'].to_s
  else
    break
  end
  #cr_object = build_cr_record_object(crr, "CrArticle")
  #puts "DOI: " + cr_object.doi.to_s + " Title: " + cr_object.title.to_s + " **References: " + cr_object.is_referenced_by_count.to_s
end

# cr_doi = "10.1039/c9sc04905c"
# crr = get_cr_pub_data(cr_doi)
#
# puts "DOI: " + crr['DOI'].to_s + " Title: " + crr['title'].to_s + crr['title'].to_s + " **References: " + crr['is-referenced-by-count'].to_s
# cr_object = build_cr_record_object(crr,"CrArticle")
# puts "DOI: " + cr_object.doi.to_s + " Title: " + cr_object.title.to_s + " **References: " + cr_object.is_referenced_by_count.to_s
# #puts crr
# underscored = underscore(CrApiWrapper.to_s)
# puts CrApiWrapper.to_s + " is " + underscored
# puts underscored + " is " + camelise(underscored)
# cr_object.instance_variables.each do |instance_variable|
#   val = cr_object.instance_variable_get(instance_variable)
#   puts "var " + instance_variable.to_s + " value " +  val.to_s
# end
# puts "Deposited date: " + cr_object.deposited.date_parts.to_s
# puts "Deposited date_tiem: " + cr_object.deposited.date_time.to_s
# puts "Deposited timestamp: " + cr_object.deposited.timestamp.to_s
