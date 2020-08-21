# Run the gem on a random sample of publications from crossref
require './lib/cr_api_wrapper'

def build_cr_record_object(doi_text)
  # A. get record data
  crr = CrApiWrapper::CrRecord.find(doi_text)
  # B. build new class using schema
  crr_properties = crr.keys
  crr_class = CrApiWrapper::CrObjectFactory.create_class "CrArticle", crr_properties
  new_cr = crr_class.new
  # C. assing object values in content to class instance
  CrApiWrapper::CrObjectFactory.assing_attributes new_cr, crr
  ls_authors = []
  #puts "***************************************************************"
  if new_cr.respond_to?('author')
    cra_keys = nil
    cra_class = nil
    craf_keys = nil
    craf_class = nil
    for an_author in new_cr.author
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
    new_cr.author = ls_authors
  end
  return new_cr
end

doi_list = CrApiWrapper::CrRecord.random(1)

doi_list.each do |cr_doi|
  crr = CrApiWrapper::CrRecord.find(cr_doi)
  puts "DOI: " + crr['DOI'].to_s + " Title: " + crr['title'].to_s  + " **References: " + crr['is-referenced-by-count'].to_s
  cr_object = build_cr_record_object(cr_doi)
  puts "DOI: " + cr_object.doi.to_s + " Title: " + cr_object.title.to_s + " **References: " + cr_object.is_referenced_by_count.to_s
end

cr_doi = "10.1039/c9sc04905c"
crr = CrApiWrapper::CrRecord.find(cr_doi)

puts "DOI: " + crr['DOI'].to_s + " Title: " + crr['title'].to_s + crr['title'].to_s + " **References: " + crr['is-referenced-by-count'].to_s
cr_object = build_cr_record_object(cr_doi)
puts "DOI: " + cr_object.doi.to_s + " Title: " + cr_object.title.to_s + " **References: " + cr_object.is_referenced_by_count.to_s
