require 'celluloid'
require 'kontena/logging'
require 'kontena/registrator/etcd'
require 'kontena/registrator/eval'

module Kontena::Registrator
  class Service
    include Kontena::Logging
    include Celluloid

    # SkyDNS example
    SKYDNS = {
      context: {
        domain: 'kontena.local',
      },
      where: [
        proc { @container.networks.has_key? 'kontena' },
        proc { !@container.networks['kontena']['IPAddress'].empty? },
      ],
      select: {
        kontena_ip: proc { @container.networks['kontena']['IPAddress'] }
      },
      etcd: proc {
        {
          "/skydns/#{@domain.split('.').reverse.join('/')}/#{@container.hostname}" => {
            host: @kontena_ip,
          }.to_json,
        }
      }
    }

    def initialize(docker_observable, config)
      @etcd_writer = Etcd::Writer.new
      @config = config

      self.async.run(docker_observable)
    end

    def eval_container(container)
      context = Eval::Context.new(container: container, **@config.fetch(:context, {}))

      @config.fetch(:where, []).each do |expr|
        if value = context.eval(expr)
          logger.debug "container=#{container} where=#{expr} match value=#{value}"
        else
          logger.debug "container=#{container} where=#{expr} skip value=#{value}"
          return
        end
      end

      @config.fetch(:select, {}).each_pair do |sym, expr|
        context.set(sym, expr)
      end

      logger.debug "container=#{container}: #{context}"

      context.eval(@config.fetch(:etcd, {})).each do |path, value|
        logger.debug "container=#{container} etcd=#{path} value=#{value.inspect}"

        yield path, value if path && value
      end
    end

    def update(docker_state)
      logger.info "Update..."
      nodes = {}
      docker_state.containers.each do |container|
        self.eval_container(container) do |path, value|
          nodes[path] = value
        end
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
