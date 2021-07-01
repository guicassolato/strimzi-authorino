# frozen_string_literal: true

class Consumer < Client
  def execute(topic:)
    say "Consuming messages from topic #{topic}\n\n"

    kafka.each_message(topic: topic) do |message|
      say "#{message.value}\n"
    end
  end
end
