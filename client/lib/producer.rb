# frozen_string_literal: true

class Producer < Client
  def execute(topic:)
    say "Producing messages to topic #{topic}\n\n"

    loop do
      say '> '
      message = gets.chomp
      begin
        kafka.deliver_message(message, topic: topic) unless message.empty?
      rescue Kafka::LeaderNotAvailable
        sleep 1
        retry
      end
    end
  end
end

