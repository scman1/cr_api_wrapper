# Run the gem on a random sample of publications from crossref
require './lib/cr_api_wrapper'

doi_list = CrApiWrapper::CrRecord.random(100)

doi_list.each do |cr_doi|
  crr = CrApiWrapper::CrRecord.find(cr_doi)
  puts "DOI: " + crr['DOI'].to_s + " Title: " + crr['title'].to_s + crr['title'].to_s
    + " **References: " + crr['is-referenced-by-count'].to_s
end

crr = CrApiWrapper::CrRecord.find("10.1039/c9sc04905c")

puts "DOI: " + crr['DOI'].to_s + " Title: " + crr['title'].to_s + crr['title'].to_s + " **References: " + crr['is-referenced-by-count'].to_s
