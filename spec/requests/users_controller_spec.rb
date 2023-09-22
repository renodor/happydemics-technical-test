# frozen_string_literal:true

require 'rails_helper'

RSpec.describe 'Widget management', type: :request do
  describe 'POST /location' do
    let(:user_id) { 1 }
    let(:latitude) { 48.843956887722015 }
    let(:longitude) { 2.391961861563238 }

    it 'returns a 201 created response' do
      post(
        '/location',
        headers: { 'X-User-Id': user_id },
        params: { latitude: latitude, longitude: longitude }
      )

      expect(response.status).to eq(201)
    end

    it 'creates location for user' do
      post(
        '/location',
        headers: { 'X-User-Id': user_id },
        params: { latitude: latitude, longitude: longitude }
      )

      timestamp = JSON.parse(response.body)['timestamp']

      # Use geohash to compare coordinate values
      geohash = REDIS_CLIENT.geohash("user:#{user_id}", timestamp).first

      REDIS_CLIENT.geoadd('any_key', [longitude, latitude, 'any_member'])

      expect(geohash).to eq(REDIS_CLIENT.geohash('any_key', 'any_member').first)
    end

    context 'when user_id header is missing' do
      it 'returns a bad_request error' do
        post(
          '/location',
          params: { latitude: latitude, longitude: longitude }
        )

        expect(response.status).to eq(400)
        expect(JSON.parse(response.body)['error']).to eq('User id header is missing')
      end
    end

    context 'when latitude param is missing' do
      it 'returns a bad_request error' do
        post(
          '/location',
          headers: { 'X-User-Id': user_id },
          params: { longitude: longitude }
        )

        expect(response.status).to eq(400)
        expect(JSON.parse(response.body)['error']).to eq('Latitude param is missing')
      end
    end

    context 'when longitude param is missing' do
      it 'returns a bad_request error' do
        post(
          '/location',
          headers: { 'X-User-Id': user_id },
          params: { latitude: latitude }
        )

        expect(response.status).to eq(400)
        expect(JSON.parse(response.body)['error']).to eq('Longitude param is missing')
      end
    end

    context 'when location cannot be created' do
      it 'returns an internal_server_error' do
        post(
          '/location',
          headers: { 'X-User-Id': user_id },
          params: { latitude: latitude, longitude: 'wrong_longitude' }
        )

        expect(response.status).to eq(500)
        expect(JSON.parse(response.body)['error']).to eq('ERR value is not a valid float')
      end
    end
  end

  describe 'GET /neighbours' do
    let(:user_id) { 1 }
    let(:user_latitude_1) { 48.844444 }
    let(:user_longitude_1) { 2.399999 }

    let(:neighbour_id) { 2 }
    let(:neighbour_latitude) { 48.844445 }
    let(:neighbour_longitude) { 2.399998 }

    let(:neighbour_2_id) { 3 }
    let(:neighbour_2_latitude) { 48.854444 }
    let(:neighbour_2_longitude) { 2.40000 }

    let(:other_user_id) { 4 }
    let(:other_user_latitude) { 7.551616 }
    let(:other_user_longitude) { -80.951614 }

    let(:current_time) { Time.current }

    before do
      Timecop.freeze(current_time)

      # Set current user location
      REDIS_CLIENT.geoadd("user:#{user_id}", [user_longitude_1, user_latitude_1, current_time.to_default_strf])

      # Set neighbours locations, less than 2000m from current user location, and less than 10 seconds ago)
      REDIS_CLIENT.geoadd("user:#{neighbour_id}", [neighbour_longitude, neighbour_latitude, (current_time - 5.seconds).to_default_strf])
      REDIS_CLIENT.geoadd("user:#{neighbour_2_id}", [user_longitude_1, user_latitude_1, (current_time - 9.seconds).to_default_strf])

      # Set another user location less than 10 seconds ago but more than 2000m from current user location
      REDIS_CLIENT.geoadd("user:#{other_user_id}", [other_user_longitude, other_user_latitude, (current_time - 1.second).to_default_strf])

      # Set another user location less than 2000m from current user location but more than 10 seconds ago
      REDIS_CLIENT.geoadd("user:#{other_user_id}", [user_longitude_1, user_latitude_1, (current_time - 10.second).to_default_strf])
    end

    it 'returns a 200 ok response' do
      get('/neighbours', headers: { 'X-User-Id': user_id })

      expect(response.status).to eq(200)
    end

    it 'returns current user and users with at least one location less than 2000m away from current user in the last 10 seconds' do
      get('/neighbours', headers: { 'X-User-Id': user_id })

      expect(JSON.parse(response.body).map { |neighbour| neighbour['id'] }).to match_array(%w[1 2 3])
    end

    it 'returns the trails of current user and its neighbours' do
      get('/neighbours', headers: { 'X-User-Id': user_id })

      JSON.parse(response.body).each do |hash|
        expect(hash['trail'].map(&:symbolize_keys)).to match_array(User.trail(key: "user:#{hash['id']}", current_time: current_time))
      end
    end

    # To completely test the feature we should make sure that the 2000m limit is well respected. For example:
    # - create a user with a location at 2000.1m from current user location and make sure it is not returned
    # - create a user with a location at 1999.9m from current user location and make sure it is returned
    it 'limits neighbours at 2000m'

    context 'when user current location is unknown' do
      it 'returns an unprocessable_entity error' do
        REDIS_CLIENT.del("user:#{user_id}")

        get('/neighbours', headers: { 'X-User-Id': user_id })

        expect(response.status).to eq(422)
        expect(JSON.parse(response.body)['error']).to eq('Cannot find neighbours as user current location is unknown')
      end
    end

    context 'when user_id header is missing' do
      it 'returns a bad_request error' do
        get('/neighbours')

        expect(response.status).to eq(400)
        expect(JSON.parse(response.body)['error']).to eq('User id header is missing')
      end
    end
  end
end
