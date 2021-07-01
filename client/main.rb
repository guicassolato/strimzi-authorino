# frozen_string_literal: true

require 'optparse'
require 'logger'

require_relative 'lib/token_provider'
require_relative 'lib/client'
require_relative 'lib/consumer'
require_relative 'lib/producer'

options = {
  api_key: ENV['API_KEY'],
  seed_brokers: 'localhost:9092',
  topic: 'my-topic',
}

OptionParser.new do |opts|
  opts.on("--mode=VALUE", "Client mode ('consumer' or 'producer')") { |value| options[:client_mode] = value }
  opts.on("--token-endpoint=VALUE", "OAuth token endpoint") { |value| options[:token_endpoint] = value }
  opts.on("--bootstrap-server=ADDRESS", "List of hostname:port of the Kafka bootstrap server") { |value| options[:seed_brokers] = value }
  opts.on("--server-ca-file-path=VALUE", "Path to the Kafka server CA cert file") { |value| options[:ca_file_path] = value }
  opts.on("--topic=VALUE", "Name of the Kafka topic name") { |value| options[:topic] = value }
  opts.on("--log-level=VALUE", "Log level (INFO, WARN, DEBUG)") { |value| options[:log_level] = value }
end.parse!

kafka_options = { seed_brokers: options[:seed_brokers] }

# oauth token
token_endpoint = options[:token_endpoint]
api_key = options[:api_key]
if token_endpoint && api_key
  token_provider = TokenProvider.new(token_endpoint, api_key)
  token_provider.get_token
  kafka_options[:sasl_oauth_token_provider] = token_provider
end

# ca cert
ca_cert_file_path = File.expand_path(options[:ca_file_path])
if File.exist?(ca_cert_file_path)
  kafka_options[:ssl_ca_cert_file_path] = ca_cert_file_path
else
  kafka_options[:ssl_ca_certs_from_system] = true
end

# logging
log_level = options[:log_level]
if log_level
  logger = Logger.new(STDOUT)
  logger.level = Logger.const_get(log_level)
  kafka_options[:logger] = logger
end

client_mode = options[:client_mode]
client_class = case client_mode
               when 'producer'
                 Producer
               when 'consumer'
                 Consumer
               else
                 raise "Unsupported client mode #{client_mode}"
               end

kafka_options[:client_id] = "kafka-#{client_mode}"

if log_level == 'DEBUG'
  logger.debug "Starting #{client_mode} with options #{kafka_options}"
end

client = client_class.new(**kafka_options)
client.execute(topic: options[:topic])
