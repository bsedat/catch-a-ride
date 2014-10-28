require 'sinatra/base'
require 'redis-sinatra'
require 'active_support/core_ext/numeric/time'

class CatchARide < Sinatra::Base
  if ENV['RACK_ENV'] == 'production'
    set :cache, Sinatra::Cache::RedisStore.new(ENV['REDISTOGO_URL'])
  else
    register Sinatra::Cache
  end

  get '/' do
    left_at = settings.cache.fetch(:left_at)
    response = '<h1>Want to catch a ride with Ben?</h1>'
    if left_at.nil?
      response << 'Sure, send him a message.'
    elsif (5.minutes.ago..Time.current).cover?(Time.at(left_at))
      response << 'Maybe. He just left so hurry up and ping him.'
    else
      response << 'Nope.'
    end
    response
  end

  get '/left' do
    if authorized?
      settings.cache.write(:left_at, Time.current.to_i, :expires_in => 18.hours)
      'OK'
    else
      reject_bad_auth!
    end
  end

  get '/undo' do
    if authorized?
      settings.cache.delete(:left_at)
      'OK'
    else
      reject_bad_auth!
    end
  end

  helpers do
    def authorized?
      @auth ||= Rack::Auth::Basic::Request.new(request.env)
      @auth.provided? && @auth.basic? && @auth.credentials && @auth.credentials == ['ben', ENV['AUTH_PASSWORD'] || '']
    end

    def reject_bad_auth!
      headers['WWW-Authenticate'] = 'Basic realm="Restricted Area"'
      status 401
      body 'Unauthorized'
    end
  end
end
