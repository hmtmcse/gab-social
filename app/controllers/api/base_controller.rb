# frozen_string_literal: true

class Api::BaseController < ApplicationController
  DEFAULT_STATUSES_LIMIT = 20
  DEFAULT_ACCOUNTS_LIMIT = 20
  DEFAULT_CHAT_CONVERSATION_LIMIT = 100
  DEFAULT_CHAT_CONVERSATION_MESSAGE_LIMIT = 20
  MAX_LIMIT_PARAM = 25
  MIN_UNAUTHENTICATED_PAGES = 1

  skip_before_action :store_current_location
  skip_before_action :check_user_permissions

  before_action :block_if_doorkeeper
  before_action :set_cache_headers

  protect_from_forgery with: :null_session

  rescue_from ActiveRecord::RecordInvalid, GabSocial::ValidationError do |e|
    render json: { error: e.to_s }, status: 422
  end

  rescue_from ActiveRecord::RecordNotFound do
    render json: { error: 'Record not found' }, status: 404
  end

  rescue_from HTTP::Error, GabSocial::UnexpectedResponseError do
    render json: { error: 'Remote data could not be fetched' }, status: 503
  end

  rescue_from OpenSSL::SSL::SSLError do
    render json: { error: 'Remote SSL certificate could not be verified' }, status: 503
  end

  rescue_from GabSocial::NotPermittedError do
    render json: { error: 'This action is not allowed' }, status: 403
  end

  def doorkeeper_unauthorized_render_options(error: nil)
    { json: { error: (error.try(:description) || 'Not authorized') } }
  end

  def doorkeeper_forbidden_render_options(*)
    { json: { error: 'This action is outside the authorized scopes' } }
  end

  protected

  def set_pagination_headers(next_path = nil, prev_path = nil)
    links = []
    links << [next_path, [%w(rel next)]] if next_path
    links << [prev_path, [%w(rel prev)]] if prev_path
    response.headers['Link'] = LinkHeader.new(links) unless links.empty?
  end

  def limit_param(default_limit)
    return default_limit unless params[:limit]
    [params[:limit].to_i.abs, MAX_LIMIT_PARAM].min
  end

  def params_slice(*keys)
    params.slice(*keys).permit(*keys)
  end

  def current_resource_owner
    ActiveRecord::Base.connected_to(role: :writing) do
      if doorkeeper_token
        @current_user ||= Rails.cache.fetch("dk:user:#{doorkeeper_token.resource_owner_id}", expires_in: 25.hours) do
            User.find(doorkeeper_token.resource_owner_id)
        end
      end
    end
    return @current_user
  end

  def current_user
    current_resource_owner || super
  rescue ActiveRecord::RecordNotFound
    nil
  end

  def require_user!
    if !current_user
      render json: { error: 'This method requires an authenticated user' }, status: 422
    elsif current_user.disabled?
      render json: { error: 'Your login is currently disabled' }, status: 403
    # : todo : when figure out email/catpcha, put this back
    # elsif !current_user.confirmed?
    #   render json: { error: 'Your login is missing a confirmed e-mail address' }, status: 403
    elsif !current_user.account.nil? and current_user.account.is_spam?
      render json: { error: 'Your account has been flagged as spam. Please contact support@sm.problemfighter.net if you believe this is an error.' }, status: 403
    elsif !current_user.approved?
      render json: { error: 'Your login is currently pending approval' }, status: 403
    end
  end

  def render_empty_success(message = nil)
    render json: { success: true, error: false, message: message }, status: 200
  end

  def authorize_if_got_token!(*scopes)
    doorkeeper_authorize!(*scopes) if doorkeeper_token
  end

  def superapp?
    return true if doorkeeper_token.nil?
    doorkeeper_token && doorkeeper_token.application.superapp? || false
  end

  def block_if_doorkeeper
    raise GabSocial::NotPermittedError unless superapp?
  end

  def set_cache_headers
    response.headers['Cache-Control'] = 'private, max-age=10'
  end
end
