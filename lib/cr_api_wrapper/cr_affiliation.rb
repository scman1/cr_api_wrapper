#lib/cr_api_wrapper/cr_affiliation.rb
require 'serrano'
require 'faraday'
require 'json'

# not needed, do it in rails

module CrApiWrapper
  class CrAffiliation
    # cr affiliation record attributes
    attr_reader :id, :article_author_id, :author_affiliation_id, :name
    # retrieves a cr affiliation object by ID
    def find(id)
      sql_statement = \
        "SELECT id, name FROM cr_affiliations WHERE id = " + id.to_s + ";"
      db = get_db()
      stm = db.prepare sql_statement
      rs = stm.execute
      values_hash = {}
      rs.each do |row|
        values_hash[row["id"]] = row["name"]
      end
      return values_hash
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
  end
end
