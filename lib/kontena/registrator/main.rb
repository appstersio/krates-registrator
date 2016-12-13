require 'celluloid'

module Kontena::Registrator
  require 'kontena/registrator/docker'

  class Main < Celluloid::Supervision::Container
    supervise type: Docker::Actor, as: :docker
  end
end
