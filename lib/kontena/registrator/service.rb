require 'celluloid'
require 'kontena/logging'
require 'kontena/registrator/etcd'

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
        proc { |container| container.networks.has_key? 'kontena' },
        proc { |container| !container.networks['kontena']['IPAddress'].empty? },
      ],
      select: {
        kontena_ip: proc { |container| container.networks['kontena']['IPAddress'] }
      },
      etcd: {
        path: [
          '/skydns',
          proc { |container, domain:, **context | domain.split('.').reverse },
          proc { |container| container.hostname },
        ],
        value: {
          host: proc { |container, kontena_ip:, **context | kontena_ip },
        }
      }
    }

    def initialize(docker_observable, config)
      @etcd_writer = Etcd::Writer.new
      @config = config

      self.async.run(docker_observable)
    end

    def eval_container(container)
      context = @config.fetch(:context, {})

      @config.fetch(:where, []).each do |expr|
        if value = container.eval(expr, context)
          logger.debug "container=#{container} where=#{expr} match value=#{value}"
        else
          logger.debug "container=#{container} where=#{expr} skip value=#{value}"
          return
        end
      end

      @config.fetch(:select, {}).each_pair do |sym, expr|
        context[sym] = container.eval(expr, context)
      end

      context.each do |key, value|
        logger.debug "container=#{container} context=#{key} value=#{value.inspect}"
      end

      if etcd_config = @config[:etcd]
        path = [container.eval(etcd_config[:path], context)].flatten.join '/'
        value = container.eval(etcd_config[:value], context).to_json

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
