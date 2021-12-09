# frozen_string_literal: true

require 'net/http'
require 'json'

class TokenProvider
  def initialize(endpoint, api_key)
    @endpoint = URI(endpoint)
    @api_key = api_key
  end

  attr_reader :endpoint, :api_key, :token

  def get_token
    Net::HTTP.start(endpoint.host, endpoint.port) do |http|
      request = Net::HTTP::Get.new(endpoint)
      request['Authorization'] = "APIKEY #{api_key}"
      response = http.request(request)
      @token = JSON.parse(response.body)['token']
    end
  end
end

