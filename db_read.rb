#!/usr/bin/ruby
require 'sqlite3'
require 'fuzzystringmatch'

class Author_Affiliation
  attr_accessor :id, :article_author_id, :name, :short_name, :add_01, :add_02,
    :add_03, :add_04, :add_05, :country
  # class attributes
  @id = nil
  @article_author_id = 0
  @name = ""
  @short_name = @add_01 = @add_02 = @add_03 = @add_04 = @add_05 = @country = ""

  # print the contents of the affiliation object
  def print()
    printf "\nAuthor ID: %d affiliation: %s affiliation short: %s country: %s\n", self.article_author_id, self.name, self.short_name, self.country
    printf "\nAddress: %s, %s, %s, %s, %s\n", self.add_01, self.add_02, self.add_03,self.add_04, self.add_05
  end

end

$affi_countries = []
$affi_institutions = []
$affi_departments = []
$affi_faculties = []
$affi_work_groups = []

def get_db
  db = SQLite3::Database.open "../ukchapp/db/development.sqlite3"
  db.results_as_hash = true
  return db
end

def start_lists
  db = get_db
  puts db.get_first_value 'SELECT SQLITE_VERSION()'
  stm = db.prepare "SELECT * FROM affiliations;"
  rs = stm.execute
  rs.each do |row|
    # printf "%s\t%s\t%s\t%s\n", row['id'], row['institution'], row['department'], row['faculty'], row['work_group'], row['country']
    if !$affi_institutions.include?(row['institution']) and row['institution']!= "" \
      and row['institution']!= nil
      $affi_institutions.append(row['institution'])
    end
    if !$affi_departments.include?(row['department']) and row['department']!= "" \
      and row['department']!= nil
      $affi_departments.append(row['department'])
    end
    if !$affi_faculties.include?(row['faculty']) and row['faculty']!= ""  \
      and row['faculty']!= nil
      $affi_faculties.append(row['faculty'])
    end
    if !$affi_work_groups.include?(row['work_group']) and row['work_group']!= "" \
      and row['work_group']!= nil
      $affi_work_groups.append(row['work_group'])
    end
    if !$affi_countries.include?(row['country']) and row['country']!= "" \
      and row['country']!= nil
      $affi_countries.append(row['country'])
    end
  end
end

def sanity_checks
  # Sanity checks
  over_ins_dep = $affi_institutions.intersection($affi_departments)
  if over_ins_dep.count > 0
    printf("%d Overlap institutions and departments\n", over_ins_dep.count)
  end
  over_ins_fac = $affi_institutions.intersection($affi_faculties)
  if over_ins_fac.count > 0
    printf("%d Overlap institutions and faculties\n", over_ins_fac.count)
  end
  over_ins_wgs = $affi_institutions.intersection($affi_work_groups)
  if over_ins_fac.count > 0
    printf("%d Overlap institutions and w. groups\n", over_ins_wgs.count)
  end
  over_dep_fac = $affi_departments.intersection($affi_faculties)
  if over_dep_fac.count > 0
    printf("%d Overlap departments and faculties\n", over_dep_fac.count)
    print over_dep_fac
  end
  over_dep_wgs = $affi_departments.intersection($affi_work_groups)
  if over_dep_wgs.count > 0
    printf("%d Overlap institutions and w. groups\n", over_dep_wgs.count)
    print over_dep_wgs
  end
  over_fac_wgs = $affi_faculties.intersection($affi_work_groups)
  if over_fac_wgs.count > 0
    printf("%d Overlap faculties and w. groups\n", over_fac_wgs.count)
    print over_fac_wgs
  end
end

def get_unique_values_list(table, field)
  sql_statement = \
    "SELECT " + field + " FROM " + table + " GROUP BY " + field + ";"
  db = get_db()
  stm = db.prepare sql_statement
  rs = stm.execute
  values_list = []
  rs.each do |row|
    values_list.append(row[field])
  end
  return values_list
end

# get the first value matching the filter_val
def get_value(table, field_val, field_ftr, filter_val)
  #print filter_val
  sql_statement = "SELECT " + field_val + " FROM " + table + " WHERE " + \
   field_ftr + " = '" + filter_val + "';"
   print sql_statement
  db = get_db()
  stm = db.prepare sql_statement
  rs = stm.execute
  retun_val = nil
  rs.each do |row|
    retun_val = row[field_val]
  end
  return retun_val
end

# get all affiliations for author
def get_author_cr_affiliations(auth_id)
  sql_statement = \
    "SELECT id, name FROM cr_affiliations WHERE article_author_id = " + auth_id.to_s + ";"
  db = get_db()
  stm = db.prepare sql_statement
  rs = stm.execute
  values_hash = {}
  rs.each do |row|
    values_hash[row["id"]] = row["name"]
  end
  return values_hash
end

# create a new affiliation object from a list of string values
def create_affi_obj(lines_list, auth_id)
  tkn_idx = 0
  auth_affi = Author_Affiliation.new()
  auth_affi.article_author_id = auth_id
  inst_found = ""
  #while tkn_idx < lines_list.count
  while tkn_idx < lines_list.count
    a_line = lines_list[tkn_idx].strip
  # lines_hash.keys.each do |line_key|
  #   a_line = lines_hash[line_key].strip
    # first element is designated as the affilition
    if tkn_idx == 0
      auth_affi.name = a_line
    elsif $affi_countries.include?(a_line)
      auth_affi.country = a_line
    elsif $affi_institutions.include?(a_line)
      if auth_affi.name != nil
        # if the affiliation name is not an institution
        # add institution to name and make short name the institution
        # otherwise shot name is the same as name
        if !$affi_institutions.include?(auth_affi.name) or \
          !$institution_synonyms.keys.include?(auth_affi.name.to_sym) then
          auth_affi.name = auth_affi.name + ", " + a_line
          auth_affi.short_name = a_line
        else
          auth_affi.short_name = auth_affi.name
        end
      end
    elsif $institution_synonyms.keys.include?(a_line.to_sym) then
      if auth_affi.name != nil
        # if the affiliation name is not an institution
        # add institution to name and make short name the institution
        # otherwise shot name is the same as name
        if !$affi_institutions.include?(auth_affi.name) and \
          !$institution_synonyms.keys.include?(auth_affi.name.to_sym) then
          auth_affi.name = auth_affi.name + ", " + $institution_synonyms[a_line.to_sym]
          auth_affi.short_name =  $institution_synonyms[a_line.to_sym]
        else
          auth_affi.short_name =  $institution_synonyms[a_line.to_sym]
        end
      end
    elsif auth_affi.add_01 == nil
      auth_affi.add_01 = a_line
    elsif auth_affi.add_02 == nil
      auth_affi.add_02 = a_line
    elsif auth_affi.add_03 == nil
      auth_affi.add_03 = a_line
    elsif auth_affi.add_04 == nil
      auth_affi.add_04 = a_line
    elsif auth_affi.add_05 == nil
      auth_affi.add_05 = a_line
    elsif auth_affi.add_05 != nil # case more than 5 tokes in address
      auth_affi.add_05 += ", " + a_line
    end
    tkn_idx += 1
  end
  # if country is missing get check all addres lines in object
  if auth_affi.country == nil
    got_it = false
    auth_affi.instance_variables.each do |instance_variable|
      # look for country name in address strings
      if instance_variable.to_s.include?("add_0") then
        #print instance_variable
        value = auth_affi.instance_variable_get(instance_variable)
        ctry = get_country(value.to_s)
        if ctry != nil then
          auth_affi.country = ctry
          value = drop_country(value)
          auth_affi.instance_variable_set(instance_variable, value)
          break
        end
      end
    end
    # look for country in affiliation name
    if auth_affi.country.to_s == ""  then
      ctry = get_country(auth_affi.name)
      auth_affi.country = ctry
    end
    # look for country in institution table
    # print auth_affi.country
    #
    if auth_affi.country.to_s == ""  then
      #printf "\n Before if %s", auth_affi.name
      inst_found = auth_affi.name
      if $affi_institutions.include?(auth_affi.name) or \
        $institution_synonyms.keys.include?(auth_affi.name.to_sym) then
        inst_found = auth_affi.name
        #printf "\n Before sendig %s", inst_found
        ctry = get_value("Affiliations", "country", "institution", inst_found.strip)
        auth_affi.country = ctry
      elsif $affi_institutions.include?(auth_affi.short_name) or \
        $institution_synonyms.keys.include?(auth_affi.short_name.to_s.to_sym) then
        inst_found = auth_affi.short_name
        #printf "\n Before sendig %s", inst_found
        ctry = get_value("Affiliations", "country", "institution", inst_found.strip)
        auth_affi.country = ctry
      end
    end
  end
  ## just for debugging
  #auth_affi.print()
  return auth_affi
end

# split the affiliation string by "," and ";" separators
def split_by_separator(affi_string, auth_id)
  tokens = []
  if affi_string.include?(",") and affi_string.include?(";")
    tokens = affi_string.split(";")
    tokens.each do |token|
      if token.include?(",")
        split_idx = tokens.find_index(token)
        temp_tkns = token.split(",")
        tokens = tokens[1..split_idx-1].concat(temp_tkns).concat(tokens[split_idx+1..])
      end
    end
  elsif affi_string.include?(",")
    tokens = affi_string.split(",")
  elsif affi_string.include?(";")
    tokens = affi_string.split(";")
  end
  if tokens != []
    return create_affi_obj(tokens, auth_id)
  else
    return nil
  end
end

# if a value in the institutions list is in string, return that value
def get_institution(affi_string)
  $affi_institutions.each do |institution|
    if affi_string.include?(institution)
      return institution
    end
  end
  return nil
end

# if a value in the institution sysnonyms list is in string, return that value
def get_institution_synonym(affi_string)
  print affi_string
  $institution_synonyms.keys.each do |inst_key|
    if affi_string.include?(inst_key.to_s)
      return inst_key.to_s
    end
  end
  return nil
end

# if a value in the departments list is in string, return that value
def get_department(affi_string)
  $affi_departments.each do |department|
    if affi_string.include?(department)
      return department
    end
  end
  return nil
end

# if a value in the faculties list is in string, return that value
def get_faculty(affi_string)
  $affi_faculties.each do |faculty|
    if affi_string.include?(faculty)
      return faculty
    end
  end
  return nil
end

# if a value in the workgroups list is in string, return that value
def get_workgroup(affi_string)
  $affi_work_groups.each do |workgroup|
    if affi_string.include?(workgroup)
      return workgroup
    end
  end
  return nil
end

# if a value in the country exeptions list is in string, remove that value
# before looking up for country
def country_exclude(affi_string)
  $country_exceptions.each do |not_a_country|
    if affi_string.include?(not_a_country)
      return affi_string.gsub(not_a_country, "")
    end
  end
  # if notting is removed
  return affi_string
end

# if a value in the country or country sysnonyms lists is in string, return that
# value (verify first that there are no country exceptions in string)
def get_country(affi_string)
  cleared_affi_string = country_exclude(affi_string)
  $affi_countries.each do |country|
    if cleared_affi_string.include?(country)
      return country
    end
  end
  $country_synonyms.keys.each do |ctry_key|
    if cleared_affi_string.include?(ctry_key.to_s)
      return $country_synonyms[ctry_key]
    end
  end
  return nil
end

# if a value in the country or country sysnonyms lists is in string, remove that
# value from the string
def drop_country(affi_string)
  dropped_country = affi_string
  $affi_countries.each do |country|
    if dropped_country.include?(country)
      dropped_country = dropped_country.gsub(country,"").strip
    end
  end
  $country_synonyms.keys.each do |ctry_key|
     if affi_string.include?(ctry_key.to_s)
       dropped_country = dropped_country.gsub(ctry_key.to_s,"").strip
     end
  end
  return dropped_country
end

# split an affiliation string using the institution and country lists and then
# build the object
def split_by_keywords(affi_string, auth_id)
  # build affiliation object directly
  # try with country and institution
  # printf "\n************************** SPLITTING BY KEYWORD *****************\n"
  # printf "Affiliation: %s\n", affi_string
  tokens=[]
  found_inst = found_country = ""
  found_inst = get_institution(affi_string)
  if found_inst == nil then
    found_inst = get_institution_synonym(affi_string)
    #printf "Institution: %s\n", found_inst
  end
  found_country = get_country(affi_string)
  if found_inst.to_s != ""
    ins_idx = affi_string.index(found_inst)
    affi_len = affi_string.length
    inst_len = found_inst.length
    if ins_idx == 0
      tokens.append found_inst
      tokens.append drop_country(affi_string[inst_len, affi_len-inst_len].strip)
      tokens.append found_country
      affi_rest = affi_string[inst_len-1, affi_len-inst_len].strip
    else
      tokens.append affi_string[0, ins_idx].strip
      tokens.append found_inst
      tokens.append drop_country(affi_string[affi_string[ins_idx+inst_len, affi_len-inst_len].strip].strip)
      tokens.append found_country
    end
    # printf"\n****************************************************************\n"
    # print tokens
    # printf"\n****************************************************************\n"
    affi_obj = create_affi_obj(tokens, auth_id)
    return affi_obj
  end
end

# determine if the string needs to be split by delimiters or by keywords and
# call the corresponding method to build the affiliation object
def split_complex(affi_string, auth_id)
  if affi_string.include?(",") or affi_string.include?(";")
    return split_by_separator(affi_string, auth_id)
  else
    return split_by_keywords(affi_string, auth_id)
  end
end

# determine if an affilition string is complex by checking if it
# contains 2 or more keywords from the common lists
def is_complex(an_item)
  occurrence_counter = 0
  #verify if item has two or more affilition elements
  if get_institution(an_item) != nil then occurrence_counter += 1 end
  if get_country(an_item) != nil then occurrence_counter += 1 end
  if get_department(an_item) != nil then occurrence_counter += 1 end
  if get_faculty(an_item) != nil then occurrence_counter += 1 end
  if get_workgroup(an_item) != nil then occurrence_counter += 1 end
  # if more than one affilition element, treat as complex
  if occurrence_counter > 1
    return true
  else
    return(false)
  end
end

# determine if an affilition string is simple by checking if it fully matches
# one of the keywords from the common lists
def is_simple(an_item)
  #verify if item has two or more affilition elements
  found_this = get_institution(an_item)
  if found_this != nil and found_this.downcase().strip == an_item.downcase().strip then return true end
  found_this = get_department(an_item)
  if found_this != nil and found_this.downcase().strip == an_item.downcase().strip then return true end
  found_this = get_faculty(an_item)
  if found_this != nil and found_this.downcase().strip == an_item.downcase().strip then return true end
  found_this = get_workgroup(an_item)
  if found_this != nil and found_this.downcase().strip == an_item.downcase().strip then return true end
  found_this = get_country(an_item)
  if found_this != nil and found_this.downcase().strip == an_item.downcase().strip then return true end
  if found_this != nil and found_this.length > an_item.length then return true end # found a country synonym
  return false
end

# verify if the affiliation object is well formed it should have a country,
# a name and a valid author ID
# (make into a method of the affi_object)
def affi_object_well_formed(affi_object, name_list, parsed_complex, auth_id)
  # problem: affi_object nil
  if affi_object == nil
    puts "\n********************* Affiliation is nil **********************\n"
    print name_list
  # problem: missing country
  elsif affi_object.country == nil
    if parsed_complex == false
      printf("\nAuthor %d affilition parsed as complex \n", auth_id)
    else
      printf("\nAuthor %d affilition parse as single \n", auth_id)
    end
    print name_list
    puts "\n************************Missing country**********************\n"
    affi_object.print()
    return false
  # problem: missing name
  elsif affi_object.name == nil
    if parsed_complex == false
      printf("\nAuthor %d affilition parsed as complex \n", auth_id)
    else
      printf("\nAuthor %d affilition parse as single \n", auth_id)
    end
    print name_list
    puts "\n************************ Missing name **********************\n"
    affi_object.print()
    return false
  # problem: missing author or author_affiliation_id incorrect
elsif affi_object.article_author_id == nil or \
   affi_object.article_author_id != auth_id
    if parsed_complex == false
      printf("\nAuthor %d affilition parsed as complex \n", auth_id)
    else
      printf("\nAuthor %d affilition parse as single \n", auth_id)
    end
    print name_list
    puts "\n************************ Wrong Author ID **********************\n"
    affi_object.print()
    return false
  else
    return true
  end
end

# insert new objects in the DB (leave for rails)
def insert_author_affiliation(affi_object, cd_affi_ids)
  # insert the object
  # get the id of the inserted object
  # update all cr_affiliations with the author_affiliation_id
  sql_statement = \
    "SELECT id, name FROM cr_affiliations WHERE article_author_id = " + affi_object.article_author_id.to_s + ";"
  db = get_db()
  #stm = db.prepare sql_statement
  #rs = stm.execute

  db.execute("INSERT INTO Author_Affiliations VALUES (?,?,?,?,?,?,?,?,?,?,?,?)", 1, affi_object.article_author_id, affi_object.name, affi_object.short_name,
     affi_object.add_01, affi_object.add_02, affi_object.add_03,affi_object.add_04, affi_object.add_05, affi_object.country,'2020-09-27','2020-09-27')
end

# list of country sysnonyms
# (need to persist somewhere)
$country_synonyms = {"UK":"United Kingdom", "U.K.":"United Kingdom",
    "U. K.":"United Kingdom", "U.K":"United Kingdom",
    "PRC":"Peoples Republic of China", "P.R.C.":"Peoples Republic of China",
    "China":"Peoples Republic of China",
    "P.R.China":"Peoples Republic of China",
    "P.R. China":"Peoples Republic of China",
    "USA":"United States of America","U.S.A.":"United States of America",
    "U. S. A.":"United States of America", "U.S.":"United States of America",
    "U. S.":"United States of America","US":"United States of America"}

# list of institution sysnonyms
# (need to persist somewhere)
$institution_synonyms = {"The ISIS facility":"ISIS Neutron and Muon Source",
    "STFC":"Science and Technology Facilities Councils",
    "Oxford University":"University of Oxford",
    "University of St Andrews":"University of St. Andrews",
    "Diamond Light Source":"Diamond Light Source Ltd.",
    "ISIS Facility":"ISIS Neutron and Muon Source"}

# list ofstrings which contain country names but are not countries, such as
# streets, institution names, etc.
# (need to persist somewhere)
$country_exceptions = ["Denmark Hill", "UK Catalysis Hub"]

# main method
begin
  start_lists
  sanity_checks
  # get the list of author ids from affiliations
  aut_list = get_unique_values_list("cr_affiliations","article_author_id")
  #print aut_list
  aut_list.each do |auth_id|
    affi_lines_hash = get_author_cr_affiliations(auth_id)
    auth_affi = nil
    split_complex = false
    # if there is only one affilition record parse as complex
    if affi_lines_hash.count == 1
      split_complex = true
      affi_line_id, affi_line_value = affi_lines_hash.first
      auth_affi = split_complex(affi_line_value, auth_id)
      continue = affi_object_well_formed(auth_affi, affi_lines_hash, split_complex, auth_id)
    else
      #printf("\nAuthor %d Mutiple affilitions complex or singles?\n", auth_id)
      #print affi_lines_hash
      single_ctr = 0
      affi_lines_hash.keys.each do |line_id|
        if is_simple(affi_lines_hash[line_id]) then
          #printf("\n%s Single", an_item)
          single_ctr += 1
        elsif is_complex(affi_lines_hash[line_id]) then
          #printf("\n%s Complex", an_item)
        else
          #printf("\n%s Single", an_item)
          single_ctr += 1
        end
      end
      if single_ctr > 1
        split_complex = false
        auth_affi = create_affi_obj(affi_lines_hash.values, auth_id)
        continue = affi_object_well_formed(auth_affi, affi_lines_hash, split_complex, auth_id)
        # if continue then
        #   insert_author_affiliation(auth_affi, affi_lines_hash.keys)
        # end
      else
        split_complex = true
        affi_lines_hash.keys.each do |line_id|
          an_affi = affi_lines_hash[line_id]
          auth_affi = split_complex(an_affi, auth_id)
          continue = affi_object_well_formed(auth_affi, affi_lines_hash, split_complex, auth_id)
        end
      end
    end
    printf " Revising: %s\n", auth_id
    auth_affi.print()
    if auth_id > 2325 then
      break
    end
    if !continue then
      print auth_id
      break
    end
  end
rescue SQLite3::Exception => e
    puts "Exception occurred"
    puts e
end
