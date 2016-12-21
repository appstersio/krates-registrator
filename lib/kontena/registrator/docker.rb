require 'celluloid'
require 'docker'
require 'docker/version_patch'
require 'pp'

require 'kontena/logging'
require 'kontena/observable'

module Kontena
  class Registrator
    # Follow Docker containers
    module Docker
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
        def [](*key)
          @json.dig(*key)
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

        # globally shared Docker state, updated by the running Docker::Actor, used
        # by other Actors. This is global, so that other Actors can continue with
        # a restarting Docker::Actor
        @observable = Kontena::Observable.new

        def self.observable
          @observable
        end

        def initialize(observable = self.class.observable)
          logger.debug "initialize: observable=#{observable}"

          @state = State.new
          @observable = observable

          # XXX: restart if returns without raising?
          self.async.run
        end

        protected

        # Synchronize container state from Docker
        #
        # @param id [String] Docker::Container ID
        def sync_container(id)
          @state.container! id, ::Docker::Container.get(id).info
        rescue ::Docker::NotFoundError
          # if the container is already gone, we may as well skip any events for it
          @state.container! id, nil
        end

        # Synchronize container states from Docker
        def start
          logger.debug "start..."

          ::Docker::Container.all(all: true).each do |container|
            logger.debug "start: container #{container.id}"

            sync_container container.id
          end

          update
        end

        # Watch container events from Docker
        def run
          self.start

          logger.debug "run..."

          ::Docker::Event.stream do |event|
            logger.debug "event: #{event.action} #{event.type} #{event.actor.id}"

            if event.type == 'container' && event.action == 'destroy'
              # the container is gone, no point trying to sync it
              @state.container! event.id, nil

            elsif event.type == 'container'
              # sync container from Docker::Event
              sync_container event.id
            else
              # ignore
              next
            end

            update
          end

        rescue ::Docker::Error::TimeoutError => error
          logger.warn "run: restart on Docker timeout: #{error}"
          raise
        end

        # Update new state to consumers
        def update
          state = @state.export

          logger.debug "update: state=#{state}"

          @observable.update(state)
        end
      end
    end
  end
end
