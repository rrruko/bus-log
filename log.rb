require 'sqlite3'
require 'net/http'
require 'json'
require 'nokogiri'

db = SQLite3::Database.new 'test.db'

rows = db.execute <<-SQL
  create table if not exists buslog (
    bus char(32) not null,
    lat char(32) not null,
    lon char(32) not null,
    heading char(8) not null,
    speed char(8) not null,
    received datetime,
    route char(16) not null default '',
    stopid char(16) not null default '',
    primary key(bus, received)
  );
SQL

loop do
  begin
    http = Net::HTTP.new('ridecenter.org', port = 7016)
    res = http.request(Net::HTTP::Get.new('/'))
    html = Nokogiri(res.body)
    json = html.root.child.content
    my_hash = JSON.parse(json)
    my_hash.each do |bus|
      stmt = <<-SQL
        insert or ignore into buslog (bus,lat,lon,heading,speed,received) values (
          ?,
          ?,
          ?,
          ?,
          ?,
          ?
        );
      SQL
      db.execute(stmt,
        [
          bus['busNumber'],
          bus['latitude'],
          bus['longitude'],
          bus['heading'],
          bus['speed'],
          bus['received'],
        ])
    end
    sleep 30
  rescue Errno::ECONNREFUSED => ex
    # swallow exception if there's a network error
    puts "#{Time.now}: #{ex}"
  end
end
