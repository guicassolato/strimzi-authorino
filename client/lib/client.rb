# frozen_string_literal: true

require 'kafka'

class Client
  def initialize(**kafka_options)
    @kafka = Kafka.new(**kafka_options)
  end

  attr_reader :kafka

  private

  def say(message)
    print(message)
  end
end
