require 'celluloid'
require 'kontena/logging'
require 'kontena/registrator/etcd'
require 'kontena/registrator/eval'

module Kontena::Registrator
  class Service
    include Kontena::Logging
    include Celluloid

    def initialize(docker_observable, policy)
      @etcd_writer = Etcd::Writer.new
      @policy = policy

      self.async.run(docker_observable)
    end

    def update(docker_state)
      logger.info "Update..."

      nodes = {}
      @policy.call(docker_state) do |container_nodes|
        nodes.merge! container_nodes
      end

      @etcd_writer.write(nodes)
    end

    def run(docker_observable)
      logger.debug "observing #{docker_observable}"

      docker_observable.observe do |docker_state|
        self.update(docker_state)
      end
    end
  end
end
