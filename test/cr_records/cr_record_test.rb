#test/cr_record/cr_record_test.rb
require './test/test_helper'

class CrossRefApiWrapperCrRecordTest < Minitest::Test

	# 0 basic test
	# test that the CR Record class exists
	def test_exists
		assert CrApiWrapper::CrRecord
	end

	# 1 test retrieve publication by DOI
	def test_retrieve_object_by_id
		VCR.use_cassette('retrieve_object_id') do
			crr = CrApiWrapper::CrRecord.find("10.1039/c9sc04905c")
			assert_equal Hash, crr.class
      # puts crr
			# Check that fields are accessible
			assert_equal "10.1039/c9sc04905c", crr['DOI']
			assert_equal 46, crr["reference-count"]
		end
	end
	# 2. dynamic creation of objects
	# this code uses the wrapper method that returns a new cr record and assings
	# the retrived values to it
	# Nested objects are returned as nested arrays and hashes
  def test_dynamic_crr_build
		VCR.use_cassette('dynamic_crr_build') do
			# A. get record data
			crr = CrApiWrapper::CrRecord.find("10.1039/c9sc04905c")
			# Check object id and type
			assert_equal "10.1039/c9sc04905c", crr['DOI']
		 	assert_equal Hash, crr.class
			# B. build new class using schema
			crr_properties = crr.keys
			crr_class = CrApiWrapper::CrObjectFactory.create_class "CrArticle", crr_properties
			new_cr = crr_class.new
			# C. assing object values in content to class instance
			puts '*******************************************************************'
			CrApiWrapper::CrObjectFactory.assing_attributes new_cr, crr
			puts new_cr
			crr.each do |field, arg|
				instance_var = field.gsub('/','_').downcase()
				instance_var = instance_var.gsub(' ','_')
				instance_var = instance_var.gsub('-','_')
				puts "property: " + instance_var + " value: " + new_cr.instance_variable_get("@#{instance_var}").to_s + " Type: " + new_cr.instance_variable_get("@#{instance_var}").class.to_s
				assert_equal arg, new_cr.instance_variable_get("@#{instance_var}")
			end
		end
	end

	# 3. create author objects from nested array in crr
	def test_dynamic_nested_build
		VCR.use_cassette('dynamic_nested_build') do
			# A. get record data
			crr = CrApiWrapper::CrRecord.find("10.1039/c9sc04905c")
			# Check object id and type
			assert_equal "10.1039/c9sc04905c", crr['DOI']
			assert_equal Hash, crr.class
			# B. build new class using schema
			crr_properties = crr.keys
			crr_class = CrApiWrapper::CrObjectFactory.create_class "CrArticle", crr_properties
			new_cr = crr_class.new
			# C. assing object values in content to class instance
			CrApiWrapper::CrObjectFactory.assing_attributes new_cr, crr
			# check that the class has an author attribute
			assert_equal true,new_cr.respond_to?('author')
			ls_authors = []
			puts "***************************************************************"
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
					puts new_cra.instance_variables.length
					cra_properties.each do |instance_var|
						instance_var = instance_var.gsub('/','_').downcase()
						instance_var = instance_var.gsub(' ','_')
						instance_var = instance_var.gsub('-','_')
						puts "property: " + instance_var + " value: " + new_cra.instance_variable_get("@#{instance_var}").to_s
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
						assert_equal ls_affiliations.length(), new_cra.affiliation.length()
						new_cra.affiliation = ls_affiliations
					end
				end
				assert_equal ls_authors.length(), new_cr.author.length()
				new_cr.author = ls_authors
			end
		end
	end

	# 4. test getting arandom list of dois
	def test_random_dois_list
		VCR.use_cassette('random_dois_list') do
			doi_list = CrApiWrapper::CrRecord.random(5)
			assert_equal Array, doi_list.class
			puts doi_list
			# Check that fields are accessible
			assert_equal 5, doi_list.length()
		end
	end
end
