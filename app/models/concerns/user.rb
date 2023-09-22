# frozen_string_literal:true

class User < ApplicationRecord
  def self.keys
    REDIS_CLIENT.keys('user:*')
  end

  def self.trail(key:, current_time:)
    ((current_time - 59.seconds).to_i..current_time.to_i).filter_map do |time|
      coordinates = REDIS_CLIENT.geopos(key, Time.at(time).utc.to_default_strf).first
      next unless coordinates

      {
        latitude: coordinates[1],
        longitude: coordinates[0]
      }
    end
  end

  # This is not really a "User" method, it should probably be in a "Location" namespace
  # Also for readability and avoid confusions it would be better to expects locations as hashes:
  # location_1 = { latitude: xxx, longitude: xxx }
  def self.distance_in_m_between(location_1, location_2)
    REDIS_CLIENT.geoadd(
      'distance_comparison',
      [location_1[0], location_1[1], 'location_1'],
      [location_2[0], location_2[1], 'location_2']
    )

    REDIS_CLIENT.geodist('distance_comparison', 'location_1', 'location_2', 'm').to_f
  end
end
