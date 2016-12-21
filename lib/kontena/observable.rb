require 'celluloid'
require 'kontena/logging'

module Kontena
  # Share a value updated by one Actor and observed by multiple Actors.
  #
  # The observing actors refresh their state based on updates to this shared value.
  # They do not necessarily care about each change, as long as they are up to date.
  class Observable
    include Kontena::Logging

    def initialize
      @value = nil
      @condition = Celluloid::Condition.new
      @active = true
    end

    # Update new state to consumers
    def update(value)
      raise "Observable is closed" unless @active

      # XXX: threadsafe?
      @value = value

      logger.debug "update: #{value}"

      @condition.broadcast
    end

    # Mark the Observable as complete.
    #
    # The Observable can no longer be updated, and all observing actors will return.
    def close
      @active = false
      @condition.broadcast
    end

    # Yield state, once at start and after each update.
    #
    # Returns once the Observable is closed.
    #
    # XXX: yield again immediately if updated during yield evaluation...
    def observe
      logger.debug "observe..."

      while @active
        # XXX: threadsafe?
        if value = @value
          logger.debug "observe: #{value}"

          yield value
        end

        if @active
          logger.debug "observe: wait..."

          @condition.wait
        end
      end
    end
  end
end
