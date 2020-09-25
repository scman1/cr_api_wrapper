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
end

# check two strings similarity
def similar(a, b)
  jarow = FuzzyStringMatch::JaroWinkler.create( :pure )
  return jarow.getDistance( a, b)
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
  # printf("\n**************************************************************\n")
  # printf("%d Institutions\n", $affi_institutions.count)
  # print $affi_institutions
  # printf("\n**************************************************************\n")
  # printf("%d Departments\n", $affi_departments.count)
  # print $affi_departments
  # printf("\n**************************************************************\n")
  # printf("%d Faculties\n", $affi_faculties.count)
  # print $affi_faculties
  # printf("\n**************************************************************\n")
  # printf("%d Work groups\n", $affi_work_groups.count)
  # print $affi_work_groups
  # printf("\n**************************************************************\n")
  # printf("%d Countries\n", $affi_countries.count)
  # print $affi_countries
  # printf("\n**************************************************************\n")
  # check ovelapping in institution, departments, faculties and workgroups
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

def get_author_cr_affiliations(auth_id)
  sql_statement = \
    "SELECT name FROM cr_affiliations WHERE article_author_id = " + auth_id.to_s + ";"
  db = get_db()
  stm = db.prepare sql_statement
  rs = stm.execute
  values_list = []
  rs.each do |row|
    values_list.append(row["name"])
  end
  return values_list
end

def create_affi_obj(tokens, auth_id)
  tkn_idx = 0
  auth_affi = Author_Affiliation.new()
  auth_affi.article_author_id = auth_id
  inst_found = false
  while tkn_idx < tokens.count
    a_token = tokens[tkn_idx].strip
    # first is commonly the affilition name
    if tkn_idx == 0
      auth_affi.name = a_token
    elsif $affi_countries.include?(a_token)
      auth_affi.country = a_token
    elsif $affi_institutions.include?(a_token)
      if auth_affi.name != nil
        auth_affi.name = auth_affi.name + ", " + a_token
        auth_affi.short_name = a_token
      end
    elsif auth_affi.add_01 == nil
      auth_affi.add_01 = a_token
    elsif auth_affi.add_02 == nil
      auth_affi.add_02 = a_token
    elsif auth_affi.add_03 == nil
      auth_affi.add_03 = a_token
    elsif auth_affi.add_04 == nil
      auth_affi.add_04 = a_token
    elsif auth_affi.add_05 == nil
      auth_affi.add_05 = a_token
    elsif auth_affi.add_05 != nil # case more than 5 tokes in address
      auth_affi.add_05 += ", " + a_token
    end
    tkn_idx += 1
  end
  # if country is missing get check all addres lines in object
  if auth_affi.country == nil
    auth_affi.instance_variables.each do |instance_variable|
      if instance_variable.to_s.include?("add_0")
        print instance_variable
        value = auth_affi.instance_variable_get(instance_variable)
        ctry = get_country(value.to_s)
        if ctry != nil
          auth_affi.country = ctry
          value = drop_country(value)
          auth_affi.instance_variable_set(instance_variable, value)
          break
        end
      end
    end
  end
  return auth_affi
end

def split_by_separator(affi_string, auth_id, separator)
  tokens = []
  tokens = affi_string.split(separator)
  return create_affi_obj(tokens, auth_id)
end

def get_institution(affi_string)
  $affi_institutions.each do |institution|
    if affi_string.include?(institution)
      return institution
    end
  end
  return nil
end

def get_department(affi_string)
  $affi_departments.each do |department|
    if affi_string.include?(department)
      return department
    end
  end
  return nil
end

def get_faculty(affi_string)
  $affi_faculties.each do |faculty|
    if affi_string.include?(faculty)
      return faculty
    end
  end
  return nil
end

def get_workgroup(affi_string)
  $affi_work_groups.each do |workgroup|
    if affi_string.include?(workgroup)
      return workgroup
    end
  end
  return nil
end

def get_country(affi_string)
  $affi_countries.each do |country|
    if affi_string.include?(country)
      return country
    end
  end
  $country_synonyms.keys.each do |ctry_key|
    if affi_string.include?(ctry_key.to_s)
      return $country_synonyms[ctry_key]
    end
  end
  return nil
end

def drop_country(affi_string)
  $affi_countries.each do |country|
    if affi_string.include?(country)
      return affi_string.gsub!(country,"").strip
    end
  end
  $country_synonyms.keys.each do |ctry_key|
    if affi_string.include?(ctry_key.to_s)
      return affi_string.gsub!(ctry_key.to_s,"").strip
    end
  end
end


def split_by_keywords(affi_string, auth_id)
  # build affiliation object directly
  # try with country and institution
  affi_obj = Author_Affiliation.new()
  affi_obj.article_author_id = auth_id
  found_inst = found_country = ""
  found_inst = get_institution(affi_string)
  found_country = get_country(affi_string)
  if found_inst.to_s != ""
    ins_idx = affi_string.index(found_inst)
    affi_len = affi_string.length
    inst_len = found_inst.length
    if ins_idx == 0
      affi_obj.name = found_inst
      affi_rest = affi_string[inst_len-1, affi_len-inst_len].strip
      affi_obj.add_01 = drop_country(affi_rest)
    else
      affi_obj.name = affi_string[0, ins_idx].strip + ", " + found_inst
      affi_obj.short_name = found_inst
      affi_rest = affi_string[ins_idx+inst_len, affi_len-inst_len].strip
      affi_obj.add_01 = drop_country(affi_rest)
    end
    if found_country.to_s != ""
      affi_obj.country = found_country
    end
    return affi_obj
  end
end

def parse_complex(affi_string, auth_id)
  if affi_string.include?(",")
    return split_by_separator(affi_string, auth_id, ",")
  elsif affi_string.include?(";")
    return split_by_separator(affi_string, auth_id, ";")
  else
    return split_by_keywords(affi_string, auth_id)
  end
end

def is_complex(an_item)
  occurrence_counter = 0
  #verify if item has two or more affilition elements
  get_institution(an_item) != nil ? occurrence_counter += 1 : printf(" no institution %d", occurrence_counter)
  get_country(an_item) != nil ? occurrence_counter += 1 : printf(" no country %d", occurrence_counter )
  get_department(an_item) != nil ? occurrence_counter += 1 : printf(" no department %d", occurrence_counter)
  get_faculty(an_item) != nil ? occurrence_counter += 1 : printf(" no faculty %d", occurrence_counter)
  get_workgroup(an_item) != nil ? occurrence_counter += 1 : printf(" no workgroup %d", occurrence_counter)
  # if more than one affilition element, treat as complex
  if occurrence_counter > 1
    return true
  else
    return(false)
  end
end

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


$country_synonyms = {"UK":"United Kingdom", "U.K.":"United Kingdom",
    "U. K.":"United Kingdom", "PRC":"Peoples Republic of China",
    "P.R.C.":"Peoples Republic of China",
    "P.R.China":"Peoples Republic of China",
    "P.R. China":"Peoples Republic of China",
    "USA":"United States of America","U.S.A.":"United States of America",
    "U. S. A.":"United States of America", "U.S.":"United States of America",
    "U. S.":"United States of America","US":"United States of America"}

begin
  start_lists
  sanity_checks
  # get the list of author ids from affiliations
  aut_list = get_unique_values_list("cr_affiliations","article_author_id")
  print aut_list
  aut_list.each do |auth_id|
    names_list = get_author_cr_affiliations(auth_id)
    if names_list.count == 1
      printf("\nAuthor %d Single affilition parse as complex \n", auth_id)
      print names_list
      auth_affi = parse_complex(names_list[0], auth_id)
      if auth_affi.country == nil
        puts "\n************************Missing country**********************\n"
      end
      printf "\nID: %d affiliation: %s affiliation short: %s country: %s\n", auth_affi.article_author_id, auth_affi.name, auth_affi.short_name, auth_affi.country
      printf "\nAddress: %s, %s, %s, %s, %s\n", auth_affi.add_01, auth_affi.add_02, auth_affi.add_03,auth_affi.add_04, auth_affi.add_05
    else
      printf("\nAuthor %d Mutiple affilitions complex or singles?\n", auth_id)
      print names_list
      single_ctr = 0
      names_list.each do |an_item|
        if is_simple(an_item) then
          printf("\n%s Single", an_item)
          single_ctr += 1
        elsif is_complex(an_item) then
          printf("\n%s Complex", an_item)
        else
          printf("\n%s Single", an_item)
          single_ctr += 1
        end
      end
      if single_ctr > 1
        print("\n***************parse list as a sigle affilition")
        auth_affi = create_affi_obj(names_list, auth_id)
        if auth_affi.country == nil
          puts "\n************************Missing country**********************\n"
        end
        printf "\nID: %d affiliation: %s affiliation short: %s country: %s\n", auth_affi.article_author_id, auth_affi.name, auth_affi.short_name, auth_affi.country
        printf "\nAddress: %s, %s, %s, %s, %s\n", auth_affi.add_01, auth_affi.add_02, auth_affi.add_03,auth_affi.add_04, auth_affi.add_05
      else
        print("\n***************parse each as complex")
        names_list.each do |an_item|
          auth_affi = parse_complex(an_item, auth_id)
          if auth_affi.country == nil
            puts "\n************************Missing country**********************\n"
          end
          printf "\nID: %d affiliation: %s affiliation short: %s country: %s\n", auth_affi.article_author_id, auth_affi.name, auth_affi.short_name, auth_affi.country
          printf "\nAddress: %s, %s, %s, %s, %s\n", auth_affi.add_01, auth_affi.add_02, auth_affi.add_03,auth_affi.add_04, auth_affi.add_05
        end
      end
    end
    if auth_id > 60
      break
    end
  end


rescue SQLite3::Exception => e
    puts "Exception occurred"
    puts e
#ensure
#    db.close if db
end
