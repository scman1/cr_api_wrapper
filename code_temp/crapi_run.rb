# CSV gem for handling csv data
require 'csv'
# JSON gem for handling json data
require 'json'
# validator from schema
require 'json_schemer'
# file manager
require 'pathname'


# Run the gem on a random sample of publications from crossref
require '../lib/cr_api_wrapper'

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

# build object from a CR record
def build_object_from_record(cr_json_object, object_class)
  # B. build new class using object keys
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
      cr_nested_object = build_object_from_record(field_value, new_class_name)
      #puts cr_nested_object
      #puts "***************************************************************"
      new_cro.instance_variable_set("@#{instance_var}", cr_nested_object)
    elsif field_type == Array
      values_list = []
      # an array can contain many objects
      # treat each array elemen as a nested object
      field_value.each do |fvs|
        cr_list_object = nil
        if fvs.class == Hash
          new_class_name = "Cr" + camelise(instance_var)
          cr_list_object = build_object_from_record(fvs, new_class_name)
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

def get_type_from_schema(key_string)
  schema_file = '../json_schema/cr_metadata_api_format_corrected.json'
  crs = get_cr_json_schema(schema_file)
  # search in properties
  type_lbl = ""
  if crs['properties'].keys.include?(key_string)
    if crs['properties'][key_string]['type'] == "array"
      type_lbl = crs['properties'][key_string]['items']['$ref']
    else
      type_lbl = crs['properties'][key_string]['type']['$ref']
    end
    type_lbl.slice!("#/definitions/")
  end
  return type_lbl
end

# use class to build CR objects
def build_cr_objects(cr_json_object, object_classes)
  # use object_classes
  # CrWork is the main object
  cro_main = object_classes['CrWork'].new
  # puts cro_main
  cro_properties = cr_json_object.keys
  cra_keys = nil
  cro_class = nil
  cro_properties.each do |instance_var|
    if cra_keys == nil or !cra_keys.include?(instance_var)
      cra_keys = cro_properties
      break
    end
  end
  # C. assing object values in content to class instance
  CrApiWrapper::CrObjectFactory.assing_attributes cro_main, cr_json_object
  # now handle nested objects
  cro_properties.each do |field|
    instance_var = field.gsub('/','_').downcase()
    instance_var.gsub!(' ','_')
    instance_var = instance_var.gsub('-','_')
    field_value = cro_main.instance_variable_get("@#{instance_var}")
    field_type = field_value.class
    #puts "Field: " + instance_var + " Type: "  + field_type.to_s + " Value: " + field_value.to_s

    if field_type == Hash
      # a hash is the representation of a nested object
      # handle this as a hash
      field_class = get_type_from_schema(field)
      cr_nested_object = nil
      if object_classes.has_key?(field_class)
        cr_nested_object = object_classes[field_class].new
      end
      if cr_nested_object != nil
        CrApiWrapper::CrObjectFactory.assing_attributes cr_nested_object, field_value
      end
      if field_class == "journal-issue"
        if cr_nested_object.published_print != nil
          date_value = cr_nested_object.published_print
          date_object = object_classes['partial-date'].new
          CrApiWrapper::CrObjectFactory.assing_attributes date_object, date_value
          cr_nested_object.published_print = date_object
        elsif cr_nested_object.published_online != nil
          date_value = cr_nested_object.published_online
          date_object = object_classes['partial-date'].new
          CrApiWrapper::CrObjectFactory.assing_attributes date_object, date_value
          cr_nested_object.published_online = date_object
        end
      end
      cro_main.instance_variable_set("@#{instance_var}", cr_nested_object)
    elsif field_type == Array
      values_list = []
      field_value.each do |fvs|
        cr_list_object = nil
        if fvs.class == Hash
          field_class = get_type_from_schema(field)
          if object_classes.has_key?(field_class)
            cr_list_object = object_classes[field_class].new
          end
          if cr_list_object != nil
            CrApiWrapper::CrObjectFactory.assing_attributes cr_list_object, fvs
            if field_class == "contributor"
              affi_objects = []
              cr_list_object.affiliation.each do |affi_value|
                affi_object = object_classes['affiliation'].new
                CrApiWrapper::CrObjectFactory.assing_attributes affi_object, affi_value
                affi_objects << affi_object
              end
              cr_list_object.affiliation = affi_objects
            end
          end
        else
          cr_list_object = fvs
        end
        values_list.append(cr_list_object)
      end
      cro_main.instance_variable_set("@#{instance_var}", values_list)
    end
  end
  return cro_main
end

# create a class name from an attribute name
def cr_class_name(attr_name)
  instance_var = attr_name.gsub('/','_').downcase()
  instance_var.gsub!(' ','_')
  instance_var = instance_var.gsub('-','_')
  class_name = "Cr" + camelise(instance_var)
  return class_name
end

# build object from CR Schema
def build_class_from_schema(cr_json_schema, object_class)
  # A. Build all nested objects
  cr_classes = {}
  if cr_json_schema.keys.include?('definitions')
    cr_definitions = cr_json_schema['definitions'].keys
    #puts "-----**********----- Definitions -----**********-----"
    #puts cr_definitions.to_s
    cr_json_schema['definitions'].each do |key, nested_object|
      #puts key + ":" + nested_object.to_s
      new_class_name = cr_class_name(key)
      #puts new_class_name
      cr_nested_class = build_simple_class(nested_object, new_class_name)
      cr_classes[key] = cr_nested_class
    end
  end
  # B. build main class using object properties
  cr_class = build_simple_class(cr_json_schema, object_class)
  #cr_properties = cr_json_schema['properties'].keys
  #cr_class = CrApiWrapper::CrObjectFactory.create_class object_class, cr_properties
  cr_classes[object_class] = cr_class
  # return the hash of cr classes
  return cr_classes
end

def build_simple_class(cr_json_schema, object_class)
  cr_class = nil
  if cr_json_schema.keys.include?('properties')
    cr_properties = cr_json_schema['properties'].keys
    cr_class = CrApiWrapper::CrObjectFactory.create_class object_class, cr_properties
    return cr_class
  end
  return cr_class
end

# verify returned files against schema
def verify_with_schema(test_file)
  schema_file = '../json_schema/cr_metadata_api_format_corrected.json'
  schema = Pathname.new(schema_file)
  schemer = JSONSchemer.schema(schema)
  json_file = nil
  File.open(test_file,"r") do |f|
    json_file = JSON.parse(f.read)
  end
  if schemer.valid?(json_file)
    # puts test_file + " matches " + schema_file
    return true
  else
    # puts "** "+test_file + " does not match " + schema_file
    return false
  end
end

# get a json object and save it locally if not recovered yet.
def get_cr_json_object(cr_doi)
  crr = nil
  doi_file = '../json_files/' + cr_doi.gsub('/','_').downcase() + '.json'
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

# get a json object and save it locally if not recovered yet.
def get_cr_json_schema(schema_file)
  crs = nil
  if File.exists?(schema_file)
    File.open(schema_file,"r") do |f|
      crs = JSON.parse(f.read)
    end
  end
  return crs
end
def get_schema_class()
  schema_file = '../json_schema/cr_metadata_api_format_corrected.json'
  crs = get_cr_json_schema(schema_file)
  # create the cr class from the schema
  cr_classes =  build_class_from_schema(crs, "CrWork")
  return cr_classes
end

def print_cr_object(cr_object)
  puts "**********************************************************************"
  puts "Deposited date: " + cr_object.deposited.date_parts.to_s
  puts "Deposited date_tiem: " + cr_object.deposited.date_time.to_s
  puts "Deposited timestamp: " + cr_object.deposited.timestamp.to_s
  puts "Content domain: " + cr_object.content_domain.domain.to_s
  puts "Content crossmark: " + cr_object.content_domain.crossmark_restriction.to_s
  puts "**********************************************************************"
  puts "Authors(first):   " + cr_object.author[0].family + " " + cr_object.author[0].given
  puts "doi:              " + cr_object.doi
  puts "title:            " + cr_object.title
  puts "pub year:         " + cr_object.issued.date_parts[0][0].to_s + + cr_object.issued.date_parts[0].to_s
  puts "pub type:         " + cr_object.type
  puts "publisher:        " + cr_object.publisher
  puts "container title:  " + cr_object.container_title.to_s
  puts "volume:           " + cr_object.volume.to_s
  puts "issue:            " + cr_object.issue.to_s
  puts "page:             " + cr_object.page.to_s
  puts "published print:  " + cr_object.published_print.to_s
  if cr_object.published_online != nil
    puts "published online: " + cr_object.published_online.date_parts[0].to_s
  end
  puts "license:          " + cr_object.license.to_s
  puts "license:          " + cr_object.license.to_s
  puts "reference count:  " + cr_object.references_count.to_s
  puts "citations:        " + cr_object.is_referenced_by_count.to_s
  puts "link:             " + cr_object.link.to_s
  puts "url:              " + cr_object.url.to_s
  puts "abstract:         " + cr_object.abstract.to_s
  if cr_object.journal_issue != nil
    puts "journal issue:    " + cr_object.journal_issue.issue.to_s + cr_object.journal_issue.published_print.to_s
  end
  puts "**************************Authors*************************************"
  cr_object.author.each do |cr_author|
    puts "given:            " + cr_author.given.to_s
    puts "family:           " + cr_author.family
    puts "sequence:         " + cr_author.sequence.to_s
    puts "orcid:            " + cr_author.orcid.to_s
    cr_author.affiliation.each do |cr_affiliation|
      puts "name:             " + cr_affiliation.name
    end
  end
  puts "**********************************************************************"
end
###############################################################################
def map_csv_work(cr_object, work_id)
  csv_record = {}
  csv_record['id'] = work_id
  csv_record['doi'] = cr_object.doi
  csv_record['title'] = cr_object.title
  csv_record['year'] = cr_object.issued.date_parts[0][0]
  csv_record['type'] = cr_object.type
  csv_record['publisher'] = cr_object.publisher
  csv_record['container'] = cr_object.container_title
  csv_record['volume'] = cr_object.volume
  # issue can come by itself or from journal_issue
  if cr_object.issue != nil
    csv_record['issue'] = cr_object.volume
  elsif cr_object.journal_issue != nil
    csv_record['issue'] = cr_object.journal_issue.issue
  else
    csv_record['issue'] = ""
  end
  csv_record['page'] = cr_object.page
  if cr_object.published_print != nil and
    cr_object.published_print.date_parts[0] != nil
    csv_record['pub_print_year'] = cr_object.published_print.date_parts[0][0]
    csv_record['pub_print_month'] = cr_object.published_print.date_parts[0][1]
    csv_record['pub_print_day'] = cr_object.published_print.date_parts[0][2]
  elsif cr_object.journal_issue != nil and
    cr_object.journal_issue.published_print != nil
    csv_record['pub_print_year'] = cr_object.journal_issue.published_print.date_parts[0][0]
    csv_record['pub_print_month'] = cr_object.journal_issue.published_print.date_parts[0][1]
    csv_record['pub_print_day'] = cr_object.journal_issue.published_print.date_parts[0][2]
  else
    csv_record['pub_print_year'] = ""
    csv_record['pub_print_month'] = ""
    csv_record['pub_print_day'] = ""
  end
  if cr_object.published_online != nil and
    cr_object.published_online.date_parts[0] != nil
    csv_record['pub_ol_year'] = cr_object.published_online.date_parts[0][0]
    csv_record['pub_ol_month'] = cr_object.published_online.date_parts[0][1]
    csv_record['pub_ol_day'] = cr_object.published_online.date_parts[0][2]
  else
    csv_record['pub_ol_day'] = ""
    csv_record['pub_ol_day'] = ""
    csv_record['pub_ol_day'] = ""
  end
  csv_record['references'] = cr_object.references_count
  csv_record['citations'] = cr_object.is_referenced_by_count
  csv_record['link'] = cr_object.link[0].url
  csv_record['url'] = cr_object.url
  csv_record['abstract'] = cr_object.abstract
  csv_record['status'] = "Added"
  csv_authors = []
  author_order = 1
  cr_object.author.each do |cr_author|
    csv_author = {}
    csv_author["work_id"] = work_id
    csv_author["given_name"] = cr_author.given
    csv_author["family_name"] = cr_author.family
    csv_author["orcid"] = cr_author.orcid.to_s
    csv_author["sequence"] = cr_author.sequence.to_s
    csv_author["order"] = author_order
    csv_authors << csv_author
    csv_affiliations = []
    affi_order = 1
    cr_author.affiliation.each do |cr_affiliation|
      csv_affiliation = {}
      csv_affiliation['id'] = work_id + author_order / 100.0
      csv_affiliation["name"] = cr_affiliation.name
      csv_affiliation["order"] = affi_order
      csv_affiliations << csv_affiliation
      affi_order += 1
    end
    csv_author["affiliation"] = csv_affiliations
    author_order += 1
  end
  csv_record['author'] = csv_authors
  return csv_record
end

def map_csv_objects(cr_objects, cr_object, work_id)
  csv_record = {}
  csv_record['id'] = work_id
  csv_record['doi'] = cr_object.doi
  csv_record['title'] = cr_object.title
  csv_record['year'] = cr_object.issued.date_parts[0][0]
  csv_record['type'] = cr_object.type
  csv_record['publisher'] = cr_object.publisher
  csv_record['container'] = cr_object.container_title
  csv_record['volume'] = cr_object.volume
  # issue can come by itself or from journal_issue
  if cr_object.issue != nil
    csv_record['issue'] = cr_object.volume
  elsif cr_object.journal_issue != nil
    csv_record['issue'] = cr_object.journal_issue.issue
  else
    csv_record['issue'] = ""
  end
  csv_record['page'] = cr_object.page

  csv_record['pub_print_year'] = ""
  csv_record['pub_print_month'] = ""
  csv_record['pub_print_day'] = ""
  if cr_object.published_print != nil and
    cr_object.published_print.date_parts[0] != nil
    csv_record['pub_print_year'] = cr_object.published_print.date_parts[0][0]
    csv_record['pub_print_month'] = cr_object.published_print.date_parts[0][1]
    csv_record['pub_print_day'] = cr_object.published_print.date_parts[0][2]
  elsif cr_object.journal_issue != nil and
    cr_object.journal_issue.published_print != nil
    csv_record['pub_print_year'] = cr_object.journal_issue.published_print.date_parts[0][0]
    csv_record['pub_print_month'] = cr_object.journal_issue.published_print.date_parts[0][1]
    csv_record['pub_print_day'] = cr_object.journal_issue.published_print.date_parts[0][2]
  end
  csv_record['pub_ol_year'] = ""
  csv_record['pub_ol_month'] = ""
  csv_record['pub_ol_day'] = ""
  if cr_object.published_online != nil and
    cr_object.published_online.date_parts[0] != nil
    csv_record['pub_ol_year'] = cr_object.published_online.date_parts[0][0]
    csv_record['pub_ol_month'] = cr_object.published_online.date_parts[0][1]
    csv_record['pub_ol_day'] = cr_object.published_online.date_parts[0][2]
  elsif cr_object.journal_issue != nil and
    cr_object.journal_issue.published_online != nil
    csv_record['pub_ol_year'] = cr_object.journal_issue.published_online.date_parts[0][0]
    csv_record['pub_ol_month'] = cr_object.journal_issue.published_online.date_parts[0][1]
    csv_record['pub_ol_day'] = cr_object.journal_issue.published_online.date_parts[0][2]
  end

  csv_record['references'] = cr_object.references_count
  csv_record['citations'] = cr_object.is_referenced_by_count
  csv_record['link'] = cr_object.link[0].url
  csv_record['url'] = cr_object.url
  csv_record['abstract'] = cr_object.abstract
  csv_record['status'] = "Added"
  csv_authors = []
  author_order = 1
  cr_object.author.each do |cr_author|
    csv_author = {}
    csv_author["work_id"] = work_id
    csv_author["given_name"] = cr_author.given
    csv_author["family_name"] = cr_author.family
    csv_author["orcid"] = cr_author.orcid.to_s
    csv_affiliation = {}
    csv_author["sequence"] = cr_author.sequence.to_s
    csv_author["order"] = author_order
    cr_objects['csv_authors'] << csv_author
    affi_order = 1
    cr_author.affiliation.each do |cr_affiliation|
      csv_affiliation['id'] = work_id + author_order / 100.0
      csv_affiliation["name"] = cr_affiliation.name
      csv_affiliation["order"] = affi_order
      cr_objects['csv_affiliations'] << csv_affiliation
      affi_order += 1
    end
    author_order += 1
  end
  cr_objects['csv_works'] << csv_record
end
# Use json schema created according to CR specification
# use json_schema validator to verify if articles match schema
doi_list = CSV.read("doi_list_short.csv", headers: true)
# puts doi_list.by_col[0]
doi_list = doi_list.by_col[0]

# doi_list.each do |cr_doi|
#   crr = get_cr_json_object(cr_doi)
#   if crr != nil
#     puts "DOI: " + crr['DOI'].to_s + " Title: " + crr['title'].to_s  + " **References: " + crr['is-referenced-by-count'].to_s
#   else
#     break
#   end
# end

# get class from the CR schema
cr_classes =  get_schema_class
# get the json object
# cr_doi = "10.1002/9783527804085.ch10"
# crr = get_cr_json_object(cr_doi)
# cr_object = build_cr_objects(crr, cr_classes)
#
# cr_object.instance_variables.each do |instance_variable|
#  val = cr_object.instance_variable_get(instance_variable)
#  puts instance_variable.to_s + "|" + val.to_s
# end
# #******************************************************************************
# print_cr_object(cr_object)

# csv_works = []
#
# csv_works << map_csv_work(cr_object, 1)

cr_objects = {'csv_works'=>[], 'csv_authors'=>[], 'csv_affiliations'=>[] }
csv_works = []
work_id = 1
doi_list.each do |cr_doi|
  crr = get_cr_json_object(cr_doi)
  cr_object = build_cr_objects(crr, cr_classes)
  #csv_works << map_csv_work(cr_object, work_id)
  #print_cr_object(cr_object)
  map_csv_objects(cr_objects, cr_object, work_id)
  work_id += 1
end

CSV.open("new_works.csv", "wb") do |csv|
  csv << cr_objects['csv_works'].first.keys # adds the attributes name on the first line
  cr_objects['csv_works'].each do |hash|
    csv << hash.values
  end
end

CSV.open("new_authors.csv", "wb") do |csv|
  csv << cr_objects['csv_authors'].first.keys # adds the attributes name on the first line
  cr_objects['csv_authors'].each do |hash|
    csv << hash.values
  end
end

CSV.open("new_affiliations.csv", "wb") do |csv|
  if cr_objects['csv_affiliations'].first != nil
    csv << cr_objects['csv_affiliations'].first.keys # adds the attributes name on the first line
    cr_objects['csv_affiliations'].each do |hash|
      csv << hash.values
    end
  end
end
