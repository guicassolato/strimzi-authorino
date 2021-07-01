# frozen_string_literal: true

require 'jwt'

class RackApp
  def call(env)
    request = Rack::Request.new(env)

    wristband_token = env['HTTP_X_EXT_AUTH_WRISTBAND']
    token = wristband_token || env['HTTP_AUTHORIZATION']

    return [404, {}, []] unless token

    encoded_jwt = token.split(' ').last
    jwt = JWT.decode(encoded_jwt, nil, false)

    response_headers = { 'Content-Type' => 'application/json' }
    response_headers['X-Ext-Auth-Wristband'] = wristband_token if wristband_token

    response_body = [jwt.first].to_json

    [200, response_headers, [response_body]]
  rescue JWT::DecodeError
    [400, {}, []]
  end
end

run RackApp.new
