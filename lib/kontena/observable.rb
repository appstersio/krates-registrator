require 'celluloid'
require 'kontena/logging'

module Kontena
  # Share a value updated by one Actor and observed by multiple Actors.
  #
  # The observing actors refresh their state based on updates to this shared value.
  # They do not necessarily care about each update, as long as they have observed
  # the most recent update.
  #
  # @attr value Most recently updated value, initially nil
  # @attr index [Integer] Incremented on each update, initially zero
  # @attr active [Boolean] Set by #close to signal #observe to stop
  # @attr condition [Celluloid::Condition] wake up idle observers on update
  class Observable
    include Celluloid
    include Kontena::Logging

    class Closed < StandardError

    end

    # Initialize with a nil value.
    #
    # Any initial #observe will block until the first #update
    def initialize
      @value = nil
      @index = 0
      @active = true

      @condition = Celluloid::Condition.new
    end

    # Update new value
    #
    # @param value the value to be yielded by #observe
    def update(value)
      raise Closed unless @active

      @value = value
      @index += 1

      logger.debug "update@#{@index}: #{value}"

      @condition.broadcast
    end

    # Mark the Observable as complete.
    #
    # The Observable can no longer be updated, and all observing actors will return.
    def close
      @active = false

      logger.debug "close@#{@index}"

      @condition.broadcast
    end

    # Yield updated value, once at start and then after each update.
    #
    # Returns once the Observable is closed.
    #
    # @yield [value]
    # @return nil
    def observe(&block)
      logger = self.logger "#{self.class.name}[#{block.object_id}]"
      logger.debug "observe..."

      index = 0

      loop do
        if @index > index && @value
          index = @index

          logger.debug "observe@#{index}: #{@value}"

          yield @value

        elsif @active
          logger.debug "observe@#{index}: wait..."

          @condition.wait

        else
          logger.debug "observe@#{index}: done"

          return
        end
      end
    end

    # Return current value, blocking if no initial value.
    #
    # @return value
    # @raise [Closed] if closed, no value to return
    def get
      observe do |value|
        return value
      end

      raise Closed
    end
  end
end
