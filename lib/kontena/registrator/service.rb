require 'celluloid'
require 'kontena/logging'
require 'kontena/registrator/etcd'
require 'kontena/registrator/eval'

module Kontena::Registrator
  class Service
    include Kontena::Logging
    include Celluloid

    ETCD_TTL = 30

    def initialize(docker_observable, policy)
      @etcd_writer = Etcd::Writer.new(ttl: ETCD_TTL)
      @policy = policy

      self.async.run(docker_observable)
      self.async.refresh
    end

    # Apply @policy, and update etcd
    #
    # @param docker_state [Docker::State]
    def update(docker_state)
      etcd_nodes = @policy.call(docker_state)

      logger.info "Update with Docker #containers=#{docker_state.containers.size} => etcd #nodes=#{etcd_nodes.size}"

      @etcd_writer.update(etcd_nodes)
    end

    # Run a refresh loop to keep etcd nodes alive
    def refresh
      interval = @etcd_writer.ttl / 2
      logger.info "refreshing etcd every #{interval}s..."

      every(interval) do
        @etcd_writer.refresh
      end
    end

    # Observe Docker::State,
    def run(docker_observable)
      logger.debug "observing #{docker_observable}"

      docker_observable.observe do |docker_state|
        self.update(docker_state)
      end
    end
  end
end
