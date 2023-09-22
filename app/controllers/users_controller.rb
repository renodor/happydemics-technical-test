# frozen_string_literal:true

class UsersController < ApplicationController
  before_action :set_current_time, :set_user_id

  def location
    return render json: { error: 'Latitude param is missing' }, status: :bad_request if params[:latitude].blank?
    return render json: { error: 'Longitude param is missing' }, status: :bad_request if params[:longitude].blank?

    REDIS_CLIENT.geoadd("user:#{@user_id}", [params[:longitude], params[:latitude], @current_time.to_default_strf])

    # We could also check that REDIS_CLIENT#geoadd is actually returning 1
    # (it is suppose to return the number of elements added to the set),
    # and return a specific error if not.

    render json: { timestamp: @current_time.to_default_strf, user_id: @user_id }, status: :created
  rescue Redis::BaseError => e
    render json: { error: e.message }, status: :internal_server_error
  end

  def neighbours
    current_user_location = REDIS_CLIENT.geopos("user:#{@user_id}", @current_time.to_default_strf).first

    return render json: { error: 'Cannot find neighbours as user current location is unknown' }, status: :unprocessable_entity if current_user_location.blank?

    neighbour_keys = User.keys.select do |key|
      ((@current_time - 9.seconds).to_i..@current_time.to_i).any? do |time|
        coordinates = REDIS_CLIENT.geopos(key, Time.at(time).utc.to_default_strf).first
        next unless coordinates

        User.distance_in_m_between(current_user_location, coordinates) <= 2000
      end
    end

    neighbour_trails = neighbour_keys.map do |neighbour_key|
      {
        id: neighbour_key.delete('user:'),
        trail: User.trail(key: neighbour_key, current_time: @current_time)
      }
    end

    render json: neighbour_trails
  end

  private

  def set_current_time
    @current_time = Time.current
  end

  def set_user_id
    @user_id = request.headers['X-User-Id']
    render json: { error: 'User id header is missing' }, status: :bad_request unless @user_id
  end
end
