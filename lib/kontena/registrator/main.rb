require 'celluloid'

module Kontena::Registrator
  require 'kontena/registrator/docker'
  require 'kontena/registrator/service'

  class Main < Celluloid::Supervision::Container
    supervise type: Docker::Actor, as: :docker

    supervise type: Service, as: :skydns, args: [Docker::Actor.observable, Service::SKYDNS]
  end
end
