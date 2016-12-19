require 'celluloid'
require 'kontena/logging'

module Kontena::Registrator
  require 'kontena/registrator/docker'
  require 'kontena/registrator/service'

  class Main < Celluloid::Supervision::Container
    include Kontena::Logging

    supervise type: Docker::Actor, as: :docker

    def register(policy)
      supervisor = Service.supervise args: [Docker::Actor.observable, policy]

      logger.info "add_service #{supervisor}: #{policy}"
    end
  end
end
