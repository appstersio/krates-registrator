require 'celluloid'
require 'kontena/logging'

module Kontena
  # Share a value updated by one Actor and observed by multiple Actors.
  #
  # The observing actors refresh their state based on updates to this shared value.
  # They do not necessarily care about each update, as long as they have observed
  # the most recent update.
  class Observable
    include Kontena::Logging

    def initialize
      @value = nil
      @index = 0
      @active = true

      @condition = Celluloid::Condition.new
      @mutex = Mutex.new
    end

    # Update new state to consumers
    def update(value)
      raise "Observable is closed" unless @active

      @mutex.synchronize {
        @value = value
        @index += 1
      }

      logger.debug "update@#{@index}: #{value}"

      @condition.broadcast
    end

    # Mark the Observable as complete.
    #
    # The Observable can no longer be updated, and all observing actors will return.
    def close
      @mutex.synchronize {
        @active = false
      }

      logger.debug "close@#{@index}"

      @condition.broadcast
    end

    # Yield state, once at start and after each update.
    #
    # Returns once the Observable is closed.
    #
    # XXX: yield again immediately if updated during yield evaluation...
    def observe
      logger = logger! progname: "#{self.class.name}[#{Thread.current}]"
      logger.debug "observe..."

      observe_index = 0

      loop do
        index = value = active = nil
        
        @mutex.synchronize {
          index = @index
          value = @value
          active = @active
        }

        if index > observe_index && value
          logger.debug "observe@#{index}: #{value}"

          yield value

          observe_index = index

        elsif active
          logger.debug "observe@#{observe_index}: wait..."

          @condition.wait

        else
          logger.debug "observe@#{observe_index}: done"

          break
        end
      end
    end
  end
end
