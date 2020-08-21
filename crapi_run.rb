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
  cro_class = CrApiWrapper::CrObjectFactory.create_class object_class, cro_properties
  new_cro = cro_class.new
  # C. assing object values in content to class instance
  CrApiWrapper::CrObjectFactory.assing_attributes new_cro, cr_json_object
  ls_authors = []
  #puts "***************************************************************"
  # now handle nested objects
  cro_properties.each do |field|
    instance_var = field.gsub('/','_').downcase()
    instance_var.gsub!(' ','_')
    instance_var = instance_var.gsub('-','_')
    field_value = new_cro.instance_variable_get("@#{instance_var}")
    field_type = field_value.class
    puts "Field: " + instance_var + " Type: "  + field_type.to_s + " Value: " + field_value.to_s
    if field_type == Hash
      # a hash is the representation of a nested object
      # handle this as a hash
      new_class_name = camelise(instance_var)
      puts "handle this as a Hash create class " + "Cr" + new_class_name
    elsif field_type == Array
      # an array can contain many objects
      # treat each array elemen as a nested object
      puts "handle this as an Array"
    end
  end

  if new_cro.respond_to?('author')
    cra_keys = nil
    cra_class = nil
    craf_keys = nil
    craf_class = nil
    for an_author in new_cro.author
      cra_properties = an_author.keys
      cra_properties.each do |instance_var|
        if cra_keys == nil or !cra_keys.include?(instance_var)
          cra_class = CrApiWrapper::CrObjectFactory.create_class "CrAuthor", cra_properties
          cra_keys = cra_properties
          break
        end
      end
      new_cra = cra_class.new
      CrApiWrapper::CrObjectFactory.assing_attributes new_cra, an_author
      ls_authors.append(new_cra)
      #puts new_cra.instance_variables.length
      cra_properties.each do |instance_var|
        instance_var = instance_var.gsub('/','_')
        instance_var = instance_var.gsub(' ','_')
        instance_var = instance_var.gsub('-','_')
        #puts "property: " + instance_var + " value: " + new_cra.instance_variable_get("@#{instance_var}").to_s
      end
      ls_affiliations = []
      # will nedd to handle multiple affiliations per author
      # look for country as an indicator of separate affiliations
      if new_cra.respond_to?('affiliation')
        for an_affiliation in new_cra.affiliation
          craf_properties = an_affiliation.keys
          craf_properties.each do |instance_var|
            if craf_keys == nil or !craf_keys.include?(instance_var)
              craf_class = CrApiWrapper::CrObjectFactory.create_class "CrAffiliation", craf_properties
              craf_keys = craf_properties
              break
            end
          end
          new_craf = craf_class.new
          CrApiWrapper::CrObjectFactory.assing_attributes new_craf, an_affiliation
          ls_affiliations.append(new_craf)
        end
        new_cra.affiliation = ls_affiliations
      end
    end
    new_cro.author = ls_authors
  end
  return new_cro
end

doi_list = CrApiWrapper::CrRecord.random(1)

doi_list.each do |cr_doi|
  crr = CrApiWrapper::CrRecord.find(cr_doi)
  puts "DOI: " + crr['DOI'].to_s + " Title: " + crr['title'].to_s  + " **References: " + crr['is-referenced-by-count'].to_s
  cr_object = build_cr_record_object(crr, "CrArticle")
  puts "DOI: " + cr_object.doi.to_s + " Title: " + cr_object.title.to_s + " **References: " + cr_object.is_referenced_by_count.to_s
end

cr_doi = "10.1039/c9sc04905c"
crr = get_cr_pub_data(cr_doi)


puts "DOI: " + crr['DOI'].to_s + " Title: " + crr['title'].to_s + crr['title'].to_s + " **References: " + crr['is-referenced-by-count'].to_s
cr_object = build_cr_record_object(crr,"CrArticle")
puts "DOI: " + cr_object.doi.to_s + " Title: " + cr_object.title.to_s + " **References: " + cr_object.is_referenced_by_count.to_s
#puts crr
underscored = underscore(CrApiWrapper.to_s)
puts CrApiWrapper.to_s + " is " + underscored
puts underscored + " is " + camelise(underscored)
cr_object.instance_variables.each do |instance_variable|
  val = cr_object.instance_variable_get(instance_variable)
  puts "var " + instance_variable.to_s + " value " +  val.to_s
end
