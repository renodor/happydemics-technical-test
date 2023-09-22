# Those seeds create 1 location per second for 3 users for the 10 next minutes
# - user with id 1 and 2 are close to each others
# - user with id 3 is far away from the others

puts 'Deleting all locations'
REDIS_CLIENT.del(REDIS_CLIENT.keys)

puts 'Creating locations for the 10 next minutes'
current_time = Time.current
(current_time.to_i..(current_time + 10.minutes).to_i).each do |time|
  REDIS_CLIENT.geoadd('user:1', [2.391961861563238, 48.843956887722015, Time.at(time).utc.to_default_strf])
  REDIS_CLIENT.geoadd('user:2', [2.391961861563239, 48.843956887722016, Time.at(time).utc.to_default_strf])
  REDIS_CLIENT.geoadd('user:3', [0, 0, Time.at(time).utc.to_default_strf])
end
