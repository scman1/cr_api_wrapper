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
  db = SQLite3::Database.open "../../ukchapp/db/development.sqlite3"
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
        if $affi_institutions.include?(auth_affi.name) or \
          $institution_synonyms.keys.include?(auth_affi.name.to_sym) then
          auth_affi.short_name = auth_affi.name
          auth_affi.add_01 = a_line
        else
          auth_affi.name = auth_affi.name + ", " + a_line
          auth_affi.short_name = a_line
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

  # make sure there is a short name, if blank make it the same as name
  if auth_affi.short_name == nil
    auth_affi.short_name = auth_affi.name
  end

  # if country is missing get check all addres lines in object
  if auth_affi.country == nil
    got_it = false
    auth_affi.instance_variables.each do |instance_variable|
      # look for country name in address strings
      if instance_variable.to_s.include?("add_0") then
        #print instance_variable
        value = auth_affi.instance_variable_get(instance_variable)
        ctry = get_country_any(value.to_s)
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
      ctry = get_country_any(auth_affi.name)
      auth_affi.country = ctry
    end
    # look for country in institution table
    if auth_affi.country.to_s == ""  then
      inst_found = auth_affi.name
      # separate lookup for sysnonyms as they are not registered as institution
      if $affi_institutions.include?(auth_affi.name)
        inst_found = auth_affi.name
        ctry = get_value("Affiliations", "country", "institution", inst_found.strip)
        auth_affi.country = ctry
      elsif $affi_institutions.include?(auth_affi.short_name)
        inst_found = auth_affi.short_name
        ctry = get_value("Affiliations", "country", "institution", inst_found.strip)
        auth_affi.country = ctry
      elsif $institution_synonyms.keys.include?(auth_affi.name.to_sym)
        inst_found = $institution_synonyms[auth_affi.name.to_sym]
        ctry = get_value("Affiliations", "country", "institution", inst_found.strip)
        auth_affi.country = ctry
      elsif $institution_synonyms.keys.include?(auth_affi.short_name.to_sym)
        inst_found = $institution_synonyms[auth_affi.short_name.to_sym]
        ctry = get_value("Affiliations", "country", "institution", inst_found.strip)
        auth_affi.country = ctry
      end
    end
  end
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
  # further split each token if they contain one keywords mixed with other
  # elements

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
def get_country_any(affi_string)
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

# if a value in the country lists is in string, return that value
def get_country(affi_string)
  cleared_affi_string = country_exclude(affi_string)
  $affi_countries.each do |country|
    if cleared_affi_string.include?(country)
      return country
    end
  end
  return nil
end

# if a value in the country sysnonyms lists is in string, return that value
def get_country_synonym(affi_string)
  cleared_affi_string = country_exclude(affi_string)
  $country_synonyms.keys.each do |ctry_key|
    if cleared_affi_string.include?(ctry_key.to_s)
      return ctry_key.to_s
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

# split an affiliation string using the entities lists and before building the
# affiliation object
def split_by_keywords(affi_string, auth_id)
  # get the indexes of each element found
  # separate the string using the indexes
  kw_indexes = {} #kewrds array of indexes and lengths
  found_inst = found_country = nil

  found_inst = get_institution(affi_string)
  if found_inst != nil then
    kw_indexes[affi_string.index(found_inst)] = found_inst.length
  end

  if found_inst == nil then
    found_inst = get_institution_synonym(affi_string)
    if found_inst != nil then
      kw_indexes[affi_string.index(found_inst)] = found_inst.length
    end
  end

  found_country = get_country(affi_string)
  if found_country != nil then
    kw_indexes[affi_string.index(found_country)] = found_country.length
  end

  found_country_synonym = get_country_synonym(affi_string)
  if found_country_synonym != nil then
    cleared_affi_string = country_exclude(affi_string)
    kw_indexes[cleared_affi_string.index(found_country_synonym)] = found_country_synonym.length
  end

  found_faculty = get_faculty(affi_string)
  if found_faculty != nil then
    kw_indexes[affi_string.index(found_faculty)] = found_faculty.length
  end

  found_workgroup = get_workgroup(affi_string)
  if found_workgroup != nil then
    kw_indexes[affi_string.index(found_workgroup)] = found_workgroup.length
  end

  found_department = get_department(affi_string)
  if found_department != nil then
    kw_indexes[affi_string.index(found_department)] = found_department.length
  end

  affiliation_array = []
  prev_split = 0
  if kw_indexes.count > 0 then
    temp_affi = affi_string
    # Order the indexes to break the affistring in its original order
    kw_indexes = kw_indexes.sort.to_h
    kw_indexes.keys.each do |kw_idx|
      # if the first index 0 make it the first element of the return array
      if affiliation_array == [] and kw_idx == 0 then
        affiliation_array = [temp_affi[kw_idx, kw_indexes[kw_idx]].strip]
      elsif affiliation_array == [] then
        affiliation_array = [temp_affi[..kw_idx-1].strip]
        affiliation_array.append(temp_affi[kw_idx, kw_indexes[kw_idx]].strip)
      elsif prev_split < kw_idx then
        affiliation_array.append(temp_affi[prev_split..kw_idx-1].strip)
        affiliation_array.append(temp_affi[kw_idx,kw_indexes[kw_idx]].strip)
      else
        affiliation_array.append(temp_affi[kw_idx,kw_indexes[kw_idx]].strip)
      end
      prev_split = kw_idx + kw_indexes[kw_idx] + 1
    end
  end
  return affiliation_array
end

# determine if the string needs to be split by delimiters or by keywords and
# call the corresponding method to build the affiliation object
def split_complex(affi_string, auth_id)
  if affi_string.include?(",") or affi_string.include?(";")
    return split_by_separator(affi_string, auth_id)
  else
    affi_tokens = split_by_keywords(affi_string, auth_id)
    return create_affi_obj(affi_tokens, auth_id)
  end
end

# determine if an affilition string is complex by checking if it
# contains 2 or more keywords from the common lists
def is_complex(an_item)
  occurrence_counter = 0
  #verify if item has two or more affilition elements
  if get_institution(an_item) != nil then occurrence_counter += 1 end
  if get_country_any(an_item) != nil then occurrence_counter += 1 end
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
  found_this = get_country_any(an_item)
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
# Update cr affiliations in DB (repace newline characters before processing)
def update_cr_affis(affi_lines)
  db = get_db()
  affi_lines.each do |cr_affi|
    cr_affi_id = cr_affi[0]
    cr_affi_name = cr_affi[1]
    sql_cmd = ""
    # puts "\n££££££££££££££££££££££££££££££££££££££££££££££££££££££££££££££££££££££££££££££££££££££££££££££"
    # print "\naffiliation STRING: " +  cr_affi_name
    # puts "\n££££££££££££££££££££££££££££££££££££££££££££££££££££££££££££££££££££££££££££££££££££££££££££££"
    if cr_affi_name.include?("\n") then
      puts "££££££££££££££££££££££££££££££££££££££££££££££££££££££££££££££££££££££££££££££££££££££££££££££"
      sql_cmd = "UPDATE cr_affiliations SET name =\"" + cr_affi_name.gsub("\n", " ") + "\" WHERE  id = " + cr_affi_id.to_s + ";"
      puts sql_cmd
      puts "££££££££££££££££££££££££££££££££££££££££££££££££££££££££££££££££££££££££££££££££££££££££££££££"
    end
    if cr_affi_name.include?("\r") then
      puts "££££££££££££££££££££££££££££££££££££££££££££££££££££££££££££££££££££££££££££££££££££££££££££££"
      sql_cmd = "UPDATE cr_affiliations SET name =\"" + cr_affi_name.gsub("\r", " ") + "\" WHERE  id = " + cr_affi_id.to_s + ";"
      puts sql_cmd
      puts "££££££££££££££££££££££££££££££££££££££££££££££££££££££££££££££££££££££££££££££££££££££££££££££"
    end
    if sql_cmd != "" then  db.execute(sql_cmd) end
  end
end

def execute_sql(sql_cmd)
  db = get_db()
  if sql_cmd != "" then  db.execute(sql_cmd) end
end

def process_multi(affi_lines, auth_id)
  affi_lines.each do |cr_line|
    # if there is an &amp: there might be two affiliations
    affi_parts = []
    if cr_line[1].include?('&amp;') then
      affi_parts = cr_line[1].split('&amp;')
    # if there is an ' and ' there might be two affiliations
    elsif cr_line[1].include?(' and ') then
      affi_parts = cr_line[1].split(' and ')
    end
    if affi_parts != []
      print "\n Length = " + cr_line[1].length.to_s + "\t" + cr_line[1]
      # check if there are more than one institutions in cr affiliation
      found_insts = []
      affi_parts.each do |affi_part|
        puts affi_part
        inst_in_part = get_institution(affi_part)
        # also try with sysnonyms
        if inst_in_part == nil
          inst_in_part = get_institution_synonym(affi_part)
        end
        if inst_in_part != nil
          found_insts.append(inst_in_part)
        end
      end
      sql_cmd = ""
      if found_insts.count > 1
        print "\nThere are two affiliations"
        affi_parts.each do |affi_part|
          if cr_line[1].index(affi_part) == 0
            print "\nUpdate " + cr_line[0].to_s + " to: " + affi_part
            affi_lines[cr_line[0]] = affi_part
            sql_cmd = "UPDATE cr_affiliations SET name =\"" + affi_part + "\" WHERE  id = " + cr_line[0].to_s + ";"
          else
            print "\nAdd new affi: " + affi_part
            sql_cmd = "INSERT INTO cr_affiliations (name, article_author_id, created_at, updated_at) Values(\"" \
               + affi_part.strip + "\", " + auth_id.to_s + ", datetime('2020-10-02'), datetime('2020-10-02'));"
            #affi_lines[cr_line[0]*100] = affi_part
          end
          puts "\n££££££££££££££££££££££££££££££££££££££££££££££££££££££££££££££££££££££££££££££££££££££££££££££\n"
          puts sql_cmd
          puts "\n££££££££££££££££££££££££££££££££££££££££££££££££££££££££££££££££££££££££££££££££££££££££££££££\n"
          execute_sql(sql_cmd)
        end
      else
        # only change if '&amp;'
        if cr_line[1].include?('&amp;') then
          print found_insts
          print "\nIt is a single affilition"
          print "\nUpdate " + cr_line[0].to_s + " to: " + cr_line[1].gsub('&amp;','&').strip
          sql_cmd = "UPDATE cr_affiliations SET name =\"" + cr_line[1].gsub('&amp;','&') + "\" WHERE  id = " + cr_line[0].to_s + ";"
          affi_lines[cr_line[0]] =  cr_line[1].gsub('&amp;','&')
          puts "\n££££££££££££££££££££££££££££££££££££££££££££££££££££££££££££££££££££££££££££££££££££££££££££££\n"
          puts sql_cmd
          puts "\n££££££££££££££££££££££££££££££££££££££££££££££££££££££££££££££££££££££££££££££££££££££££££££££\n"
          execute_sql(sql_cmd)
        end
      end
      print "\nAffi lines"
      print affi_lines
    end
  end
  affi_lines = get_author_cr_affiliations(auth_id)
  return affi_lines
end

def affi_splits(affi_lines)
  all_insts=[]
  temp_lines = affi_lines
  return_splits = []
  affi_lines.each do |a_line|
    inst_found = get_institution(a_line)
    if inst_found == nil then
      inst_found = get_institution_synonym(a_line)
    end
    if inst_found != nil and inst_found.to_s.downcase.strip == a_line.to_s.downcase.strip then
      all_insts.append(affi_lines.find_index(a_line))
    end
  end
  prev_idx = 0
  if all_insts.count > 1
    all_insts[1..].each do |inst_indx| #ignore the first index
      # distance between institution has to be greather than 1
      # 0 and 1, for instance can have institutions such as UKCH+RCaH
      # ignore the two first occurrences
      if inst_indx > 1 and inst_indx-1 > prev_idx
        return_splits.append(temp_lines[prev_idx..inst_indx-1])
        prev_idx = inst_indx
      end
    end
  end
  if prev_idx != 0
    return_splits.append(temp_lines[prev_idx.. ])
  else
    return_splits = [affi_lines]
  end
  return return_splits
end

# list of country sysnonyms
# (need to persist somewhere)
$country_synonyms = {"(UK)":"United Kingdom", "UK":"United Kingdom",
  "U.K.":"United Kingdom", "U. K.":"United Kingdom", "U.K":"United Kingdom",
    "PRC":"Peoples Republic of China", "P.R.C.":"Peoples Republic of China",
    "China":"Peoples Republic of China",
    "P.R.China":"Peoples Republic of China",
    "P.R. China":"Peoples Republic of China",
    "USA":"United States of America","U.S.A.":"United States of America",
    "United States":"United States of America",
    "U. S. A.":"United States of America", "U.S.":"United States of America",
    "U. S.":"United States of America","US":"United States of America"}

# list of institution sysnonyms
# (need to persist somewhere)
$institution_synonyms = {"The ISIS facility":"ISIS Neutron and Muon Source",
    "STFC":"Science and Technology Facilities Councils",
    "Oxford University":"University of Oxford",
    "University of St Andrews":"University of St. Andrews",
    "Diamond Light Source Ltd Harwell Science and Innovation Campus":"Diamond Light Source Ltd.",
    "Diamond Light Source":"Diamond Light Source Ltd.",
    "ISIS Facility":"ISIS Neutron and Muon Source",
    "University College of London":"University College London"}

# list ofstrings which contain country names but are not countries, such as
# streets, institution names, etc.
# (need to persist somewhere)
$country_exceptions = ["Denmark Hill", "UK Catalysis Hub"]

# main method
# split the affiliations contained in CR affiliation table
begin
  start_lists
  sanity_checks
  # get the list of author ids from affiliations
  aut_list = get_unique_values_list("cr_affiliations","article_author_id")
  # first pass split multiple affiliations
  # go trough all authors, and if multiple split, replace record with new
  # affiliation and add a new affiliation for author
  aut_list.each do |auth_id|
    affi_lines = get_author_cr_affiliations(auth_id)
    num_lines = affi_lines.count
    # check if affi lines may contian more than one affiliation
    affi_lines = process_multi(affi_lines, auth_id)
    if affi_lines.count > num_lines
      break # stop if a line is added
    end
    # check if a group of affiliation lines correspods to a single affiliation
    # or to many
    single_ctr = 0
    affi_lines.keys.each do |line_id|
      if is_simple(affi_lines[line_id]) then
        printf("\n%s Single", affi_lines[line_id])
        single_ctr += 1
      elsif is_complex(affi_lines[line_id]) then
        single_ctr = 0
        printf("\n%s Complex", affi_lines[line_id])
      else
        printf("\n%s Single", affi_lines[line_id])
        single_ctr += 1
      end
    end
    if single_ctr > 1
      print "\n"
      print affi_lines
      print "\nProcess lines as one affiliation?"
      affi_split = affi_splits(affi_lines.values) # for cases when multiple affiliations stored vertically
      affi_split.each do | an_affi|
        auth_affi = create_affi_obj(an_affi, auth_id)
        continue = affi_object_well_formed(auth_affi, affi_lines, false, auth_id)
        auth_affi.print()
      end
    else
      print "\n"
      print affi_lines
      print "\nProcess each line as complex affiliation(s)"
      affi_lines.keys.each do |line_id|
        an_affi = affi_lines[line_id]
        auth_affi = split_complex(an_affi, auth_id)
        continue = affi_object_well_formed(auth_affi, affi_lines, true, auth_id)
        auth_affi.print()
      end
    end
  end
rescue SQLite3::Exception => e
    puts "Exception occurred"
    puts e
end
