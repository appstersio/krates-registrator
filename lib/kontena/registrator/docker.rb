require 'celluloid'
require 'docker'
require 'docker/version_patch'
require 'pp'

require 'kontena/logging'
require 'kontena/observable'

# Follow Docker containers
module Kontena::Registrator::Docker
  # Immutable container state
  class Container
    attr_accessor :id

    def initialize(id, json)
      @id = id
      @json = json

      self.freeze
    end

    def to_s
      name
    end

    # Dig into JSON fields
    #
    # Normalizes empty strings to nil
    def [](*key)
      value = @json.dig(*key)
      value = nil if value == ""
      value
    end

    def name
      self['Name'].split('/').last
    end

    def hostname
      self['Config', 'Hostname']
    end

    def networks
      self['NetworkSettings', 'Networks']
    end

    def network(name)
      self['NetworkSettings', 'Networks', name]
    end

    def network_ip(name)
      self['NetworkSettings', 'Networks', name, 'IPAddress']
    end
  end

  # Mutable Docker engine state, which can be frozen immutable for export
  class State
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
    # @return [Kontena::Registrator::Docker::Container]
    def container!(id, json)
      if json
        #pp(json)

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

  # Observe Docker State
  class Actor
    include Kontena::Logging
    include Celluloid

    # @param observable [Kontena::Observable<State>]
    def initialize(observable, start: true)
      logger.debug "initialize: observable=#{observable}"

      @state = State.new
      @observable = observable

      self.start if start
    end

    def start
      logger.debug "start..."

      # List Docker containers for initial state
      self.sync_state

      # Loop Docker events to update state
      self.async.run
    end

    # Synchronize container state from Docker
    #
    # @param id [String] Docker::Container ID
    # @return [Kontena::Registrator::Docker::Container]
    def sync_container(id)
      @state.container! id, Docker::Container.get(id).info
    rescue Docker::Error::NotFoundError
      # if the container is already gone, we may as well skip any events for it
      @state.container! id, nil
    end

    # Synchronize inital container state from Docker
    def sync_state
      logger.debug "sync..."

      Docker::Container.all(all: true).each do |container|
        logger.debug "sync: container #{container.id}"

        sync_container container.id
      end

      update!
    end

    # Watch container events from Docker
    def run
      logger.debug "run..."

      Docker::Event.stream do |event|
        logger.debug "event: #{event.action} #{event.type} #{event.actor.id}"

        if event.type == 'container' && event.action == 'destroy'
          # the container is gone, no point trying to sync it
          container = @state.container! event.id, nil

          logger.info "destroy container #{event.id}: #{container}"

        elsif event.type == 'container'
          # sync container from Docker::Event
          container = sync_container event.id

          logger.info "#{event.action} container #{event.id}: #{container}"

        else
          # ignore
          next
        end

        update!
      end

    rescue Docker::Error::TimeoutError => error
      logger.warn "run: restart on Docker timeout: #{error}"
      raise
    end

    # Update new state to observable
    def update!
      state = @state.export

      logger.debug "update: state=#{state}"

      @observable.update(state)
    end
  end
end
