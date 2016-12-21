require 'celluloid'

require 'kontena/logging'
require 'kontena/observable'

module Kontena
  class Registrator < Celluloid::Supervision::Container
    require 'kontena/registrator/docker'
    require 'kontena/registrator/policy'
    require 'kontena/registrator/service'

    include Kontena::Logging

    def initialize(**opts)
      super(**opts)

      # Shared Docker state, updated by the running Docker::Actor, used
      # by other Service actors.
      #
      # If the Docker::Actor restarts, it will simply reload the Docker::State, and
      # continue updating the same Observable.
      #
      # Other Actors do not need to be restarted, they will pick up the refreshed state.
      @docker_observable = Kontena::Observable.new # Docker::State

      # Updates the global Docker::Actor.observable
      supervise type: Docker::Actor, as: :docker, args: [@docker_observable]
    end

    # Supervise a new Service for the given Policy
    #
    # Uses the shard Docker::Actor.observable
    #
    # @param policy [Kontena::Registrator::Policy]
    def register(policy)
      supervisor = supervise type: Service, args: [@docker_observable, policy]

      logger.info "register #{policy.name}: #{supervisor}"
    end
  end
end
