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
  while tkn_idx < tokens.count
    a_token = tokens[tkn_idx].strip
    if tkn_idx == 0
      auth_affi.name = a_token
    elsif $affi_countries.include?(a_token)
      auth_affi.country = a_token
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
    end
    tkn_idx += 1
  end
  return auth_affi
end

def split_by_separator(affi_string, auth_id, separator)
  tokens = []
  tokens = affi_string.split(separator)
  return create_affi_obj(tokens, auth_id)
end

def split_by_keywords(affi_string, auth_id)
  #try with country and institution
  tokens = []
  found_inst = found_country = ""
  $affi_institutions.each do |institution|
    if affi_string.include?(institution)
      found_inst = institution
      break
    end
  end
  $affi_countries.each do |country|
    if affi_string.include?(country)
      found_country = country
      break
    end
  end
  if found_country == ""
    $country_synonyms.keys.each do |ctry_key|
      if affi_string.include?(ctry_key.to_s)
        found_country = $country_synonyms[ctry_key]
        break
      end
    end
  end
  if found_inst != ""
    ins_idx = affi_string.index(found_inst)
    ctry_idx = affi_string.index(found_country)
    affi_start= affi_mid = affi_rest = ""
    affi_len = affi_string.length
    inst_len = found_inst.length
    if ins_idx == 0
      affi_start =  found_inst
      affi_rest = affi_string[inst_len-1, affi_len-inst_len].strip
    else
      affi_start =  affi_string[0, ins_idx].strip
      affi_mid = found_inst
      affi_rest = affi_string[ins_idx+inst_len, affi_len-inst_len].strip
    end
    if affi_start != ""
      tokens.append(affi_start)
    end
    if affi_mid != ""
      tokens.append(affi_mid)
    end
    if affi_rest != ""
      tokens.append(affi_rest)
    end
    if found_country != ""
      tokens.append(found_country)
    end
    return create_affi_obj(tokens, auth_id)
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

$country_synonyms = {"UK":"United Kingdom", "U.K.":"United Kingdom",
    "U. K.":"United Kingdom", "PRC":"Peoples Republic of China",
    "P.R.C.":"Peoples Republic of China",
    "P.R.China":"Peoples Republic of China",
    "P.R. China":"Peoples Republic of China",
    "USA":"United States of America","U.S.A.":"United States of America",
    "U.S.":"United States of America", "U. S. A.":"United States of America",
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
      printf "\nID: %d affiliation: %s country: %s\n", auth_affi.article_author_id, auth_affi.name, auth_affi.country
      printf "\nAddress: %s, %s, %s, %s, %s\n", auth_affi.add_01, auth_affi.add_02, auth_affi.add_03,auth_affi.add_04, auth_affi.add_05
    else
      printf("\nAuthor %d Mutiple affilitions complex or singles?\n", auth_id)
      print names_list
    end
    if auth_id > 60
      break
    end
  end
  # cr_affiliation
  # db = get_db
  # stm = db.prepare "SELECT * FROM cr_affiliations;"
  # rs = stm.execute
  # ctr_idx = 0
  # author_id = 0
  # $affi_names = []
  # rs.each do |row|
  #   this_name = row['name']
  #   this_author = row['article_author_id']
  #   printf "%s\t%s\tAuthor: %s\n", row['id'], this_name, this_author
  #   if ctr_idx >= 18
  #     break
  #   end
  #
  #   $synonyms={"UK":"United Kingdom", "U.K.":"United Kingdom",
  #      "PRC":"Peoples Republic of China"}
  #   # if $affi_institutions.include?(this_name)
  #   #   printf "\n***** %s is in institutions list\n", this_name
  #   # elsif $affi_departments.include?(this_name)
  #   #   printf("\n***** %s is in departments list\n", this_name)
  #   # elsif $affi_faculties.include?(this_name)
  #   #   printf("\n***** %s is in faculties list\n", this_name)
  #   # elsif $affi_work_groups.include?(this_name)
  #   #   printf("\n***** %s is in work groups list\n", this_name)
  #   # elsif $affi_countries.include?(this_name)
  #   #   printf("\n***** %s is in countries list\n", this_name)
  #   # end
  #   if author_id == 0
  #     author_id = this_author
  #     $affi_names.append(this_name)
  #   elsif author_id == this_author
  #     $affi_names.append(this_name)
  #   else
  #     # parse affi names
  #     printf "\nNeed to parse:\n"
  #     print $affi_names
  #     printf "\nFor author: %d\n", author_id
  #     author_id = this_author
  #     $affi_names = [this_name]
  #   end
  #
  #   ctr_idx += 1
  # end

rescue SQLite3::Exception => e
    puts "Exception occurred"
    puts e
#ensure
#    db.close if db
end
