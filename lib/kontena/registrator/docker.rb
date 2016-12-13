require 'celluloid'
require 'docker'
require 'kontena/logging'

module Kontena::Registrator::Docker
  class State
    # Immutable container state
    class Container
      attr_accessor :id

      def initialize(id, json)
        @id = id
        @json = json

        self.freeze
      end

      def name
        @json['Name'].split('/').last
      end
    end

    def initialize(containers = { })
      @containers = containers
    end

    def containers
      @containers.each_value
    end

    # Update container state from JSON, or remove container from state
    #
    # @param [String] id
    # @param [Hash, Nil] json
    def container!(id, json)
      if json
        @containers[id] = Container.new(id, json)
      else
        @containers.delete(id)
      end
    end

    # Return a new frozen copy of the state
    def export
      state = self.class.new(@containers.clone.freeze)
      state.freeze

      return state
    end
  end

  class Actor
    include Kontena::Logging
    include Celluloid

    def initialize
      logger.debug "Initialize"

      @state = State.new
      @export = nil
      @condition = Celluloid::Condition.new

      self.async.run
    end

    # Synchronize container state from Docker
    #
    #
    def sync(container)
      @state.container! container.id, container.json
    rescue Docker::NotFoundError
      # if the container is already gone, we may as well skip any events for it
      @state.container! container.id, nil
    end

    # Synchronize container states from Docker
    def start
      logger.debug "start..."

      Docker::Container.all.each do |container|
        logger.debug "start: container #{container.id}"

        sync container
      end

      push
    end

    def run
      self.start

      logger.debug "run..."

      Docker::Event.stream do |event|
        logger.debug "event: #{event.action} #{event.type} #{event.actor.id}"

        if event.type == 'container' && event.action == 'destroy'
          # the container is gone, no point trying to sync it
          @state.container! event.id, nil

        elsif event.type == 'container'
          # sync container from Docker::Event
          sync Docker::Container.new(Docker.connection, {id: event.id}.merge(event.actor.attributes))
        else
          # ignore
          next
        end

        push
      end

    rescue Docker::Error::TimeoutError => error
      logger.warning "run: restart on Docker timeout: #{error}"
    end

    # Update new state to consumers
    def push
      @export = @state.export

      logger.debug "push: signal export=#{@export.inspect}"

      @condition.signal
    end

    # Yield state, once at start and after each update
    def pull
      logger.debug "pull..."
      
      loop do
        if export = @export
          logger.debug "pull: export=#{export.inspect}"

          yield export
        end

        logger.debug "pull: wait..."

        @condition.wait
      end
    end
  end
end
