require 'json_schemer'

require 'pathname'

require 'json'

schema_file = './json_files/cr_metadata_api_format_corrected.json'
schema = Pathname.new(schema_file)

schemer = JSONSchemer.schema(schema)

puts(schemer)

test_file = './json_files/cr_test_retrieved.json'
json_file = nil
File.open(test_file,"r") do |f|
  json_file = JSON.parse(f.read)
end

puts("Test file is OK?: " + schemer.valid?(json_file).to_s)

if schemer.valid?(json_file)
  cr_schema = nil
  File.open(schema_file,"r") do |f|
    cr_schema = JSON.parse(f.read)
  end
  if cr_schema != nil
    puts "writting schema"
    File.open(schema_file,"w") do |f|
      f.write(JSON.pretty_generate(cr_schema))
    end
  end
  puts test_file + " matches " + schema_file
end
