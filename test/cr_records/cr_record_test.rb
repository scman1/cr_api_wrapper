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
  def test_dynamic_do_build
		VCR.use_cassette('dynamic_do_build') do
			# A. get record data
			crr = CrApiWrapper::CrRecord.find("10.1039/c9sc04905c")
			# Check object id and type
			assert_equal "10.1039/c9sc04905c", crr['DOI']
		 	assert_equal Hash, crr.class
			# # B. get schema
			# #     The schema will be used to build a DO class dinamically
			# do_schema = CordraRestClient::DigitalObject.get_schema(API_URL, cdo.type.gsub(" ","%20"))
			# # check that the result is saved
			# assert_equal "object", do_schema["type"]
			# assert_equal "DigitalSpecimen", do_schema["title"]
			# B. build new class using schema
			crr_properties = crr.keys
			crr_class = CrApiWrapper::CrObjectFactory.create_class "CrArticle", crr_properties
			new_cr = crr_class.new
			# C. assing object values in content to class instance
			CrApiWrapper::CrObjectFactory.assing_attributes new_cr, crr
			crr.each do |field, arg|
				instance_var = field.gsub('/','_')
				instance_var = instance_var.gsub(' ','_')
				instance_var = instance_var.gsub('-','_')
				assert_equal arg, new_cr.instance_variable_get("@#{instance_var}")
				puts "property: " + instance_var + " value: " + new_cr.instance_variable_get("@#{instance_var}").to_s + new_cr.instance_variable_get("@#{instance_var}").class.to_s
			end
		end
	end

end
