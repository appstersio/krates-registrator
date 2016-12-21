require 'celluloid'

require 'kontena/logging'

module Kontena
  class Registrator < Celluloid::Supervision::Container
    require 'kontena/registrator/docker'
    require 'kontena/registrator/policy'
    require 'kontena/registrator/service'

    include Kontena::Logging

    supervise type: Docker::Actor, as: :docker

    def register(policy)
      supervisor = Service.supervise args: [Docker::Actor.observable, policy]

      logger.info "add_service #{supervisor}: #{policy}"
    end
  end
end
