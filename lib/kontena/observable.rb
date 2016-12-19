require 'celluloid'
require 'kontena/logging'

module Kontena
  class Observable
    include Kontena::Logging

    def initialize
      @value = nil
      @condition = Celluloid::Condition.new
    end

    # Update new state to consumers
    def update(value)
      # XXX: threadsafe?
      @value = value

      logger.debug "update: #{value}"

      @condition.signal
    end

    # Yield state, once at start and after each update
    #
    # XXX: yield again immediately if updated during yield evaluation...
    def observe
      logger.debug "observe..."

      loop do
        # XXX: threadsafe?
        if value = @value
          logger.debug "observe: #{value}"

          yield value
        end

        logger.debug "observe: wait..."

        @condition.wait
      end
    end
  end
end
