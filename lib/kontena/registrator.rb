require 'celluloid'

require 'kontena/logging'

module Kontena
  class Registrator < Celluloid::Supervision::Container
    require 'kontena/registrator/docker'
    require 'kontena/registrator/policy'
    require 'kontena/registrator/service'

    include Kontena::Logging

    # Update the global Docker::Actor.observable
    supervise type: Docker::Actor, as: :docker

    # Supervise a new Service for the given Policy
    #
    # Uses the shard Docker::Actor.observable
    #
    # @param policy [Kontena::Registrator::Policy]
    def register(policy)
      supervisor = Service.supervise args: [Docker::Actor.observable, policy]

      logger.info "add_service #{supervisor}: #{policy}"
    end
  end
end
