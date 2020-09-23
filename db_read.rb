#!/usr/bin/ruby

require 'sqlite3'

begin

    db = SQLite3::Database.open "../ukchapp/db/development.sqlite3"
    db.results_as_hash = true
    puts db.get_first_value 'SELECT SQLITE_VERSION()'

    stm = db.prepare "SELECT * FROM affiliations;"
    rs = stm.execute

    rs.each do |row|
      printf "%s\t%s\t%s\t%s\n", row['id'], row['institution'], row['department'], row['country']
    end

rescue SQLite3::Exception => e

    puts "Exception occurred"
    puts e

ensure
    db.close if db
end
