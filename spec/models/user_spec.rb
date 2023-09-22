# frozen_string_literal:true

require 'rails_helper'

RSpec.describe User, type: :model do
  describe '.ids' do
    before do
      REDIS_CLIENT.geoadd('user:1', [10, 10, Time.current.to_default_strf])
      REDIS_CLIENT.geoadd('user:2', [11, 11, Time.current.to_default_strf])
      REDIS_CLIENT.geoadd('other_key', [0, 0, Time.current.to_default_strf])
    end

    it 'returns user keys' do
      expect(described_class.keys).to match_array(['user:1', 'user:2'])
    end
  end

  describe '.trail' do
    let(:user_id) { 1 }
    let(:user_key) { "user:#{user_id}" }
    let(:current_latitude) { 48.85 }
    let(:current_longitude) { 2.40 }
    let(:trail_latitude) { 48.84 }
    let(:trail_longitude) { 2.39 }
    let(:other_latitude) { 33.33 }
    let(:other_longitude) { 22.22 }
    let(:current_time) { Time.current }
    let(:user_trail) { described_class.trail(key: user_key, current_time: current_time) }

    before do
      Timecop.freeze(current_time)

      # Set user location of the last 60 seconds:
      # - 1st second (current time), user is at lat 48.85, long 2.40
      # - 59 other seconds, user is at lat 48.84, long 2.39
      ((current_time - 59.seconds).to_i..current_time.to_i).each_with_index do |time, index|
        longitude = index.zero? ? current_longitude : trail_longitude
        latitude = index.zero? ? current_latitude : trail_latitude

        REDIS_CLIENT.geoadd(user_key, [longitude, latitude, Time.at(time).utc.to_default_strf])
      end

      # Set another user location before the last 60 seconds
      ((current_time - 99.seconds).to_i..(current_time - 60.seconds).to_i).each do |time|
        REDIS_CLIENT.geoadd(user_key, [other_longitude, other_latitude, Time.at(time).utc.to_default_strf])
      end
    end

    it 'only returns user locations for the last 60 seconds' do
      expect(user_trail.length).to eq(60)
    end

    it 'returns the correct user locations for the last 60 seconds' do
      expect(user_trail.first[:latitude].to_f.round(2)).to eq(current_latitude)
      expect(user_trail.first[:longitude].to_f.round(2)).to eq(current_longitude)

      expect(user_trail[1..].map { |location| location[:latitude].to_f.round(2) }.uniq).to eq([trail_latitude])
      expect(user_trail[1..].map { |location| location[:longitude].to_f.round(2) }.uniq).to eq([trail_longitude])
    end

    context 'when some of user locations are unknown' do
      it 'does not return empty locations' do
        expect(described_class.trail(key: user_key, current_time: current_time + 10.seconds).length).to eq(50)
      end
    end
  end

  describe 'distance_in_m_between' do
    let(:paris) { [2.2769956, 48.8588336] }
    let(:marseille_vieux_port) { [5.375358, 43.2948615] }
    let(:marseille_opera) { [5.3731807, 43.2956916] }

    it 'returns distance in meter between the two given locations' do
      expect(described_class.distance_in_m_between(paris, paris)).to eq(0.0)
      expect(described_class.distance_in_m_between(paris, marseille_vieux_port)).to eq(663_279.6699)
      expect(described_class.distance_in_m_between(marseille_vieux_port, marseille_opera)).to eq(199.0919)
      expect(described_class.distance_in_m_between(marseille_vieux_port, marseille_opera)).to eq(described_class.distance_in_m_between(marseille_opera, marseille_vieux_port))
    end
  end
end
