require 'celluloid'

require 'kontena/logging'

# Start/stop services from configuration udpates
class Kontena::Registrator::Manager
  include Celluloid
  include Kontena::Logging

  class ServiceError < StandardError

  end

  def initialize(configuration_observable, services, service_class, service_opts = { }, start: true)
    @configuration_observable = configuration_observable
    @services = services
    @class = service_class
    @opts = service_opts

    self.start if start
  end

  def start
    logger.debug "start..."

    self.async.run
  end

  def apply(config_state)
    logger.debug "apply..."

    # sync up sevices
    config_state.each do |policy, config|
      logger.debug "apply policy=#{policy} with config=#{config.to_s}: #{config.to_json}"

      begin
        if self[policy, config].nil?
          self.create(policy, config)
        elsif config
          self.reload(policy, config)
        end
      rescue ServiceError => error
        # skip, omit from @services, and thus retry on next config update
        logger.error error
      end
    end

    # sync down services
    self.each do |policy, config_key|
      unless config_state.include? policy, config_key
        self.remove(policy, config_key)
      end
    end
  end

  def run
    @configuration_observable.observe do |config_state|
      apply(config_state)
    end
  end

  # Manager API

  # TODO: trap_exit

  # Get Service for policy, with optional config
  #
  # @param policy [Kontena::Registrator::Policy]
  # @param config policy configuration object
  # @return [Service]
  def [](policy, config = nil)
    @services[[policy, config ? config.to_s : nil]]
  end

  # @yield [policy, config_key]
  # @yieldparam policy [Kontena::Registrator::Policy]
  # @yieldparam config_key [String, nil]
  def each(&block)
    @services.each do |key, service|
      policy, config_key = key
      yield policy, config_key
    end
  end

  # Is the service running?
  #
  # @param policy [Kontena::Registrator::Policy]
  # @param config [nil, Kontena::Registrator::Policy::Config]
  def status(policy, config = nil)
    self[policy, config]
  end

  # Supervise a new Service for the given Policy and optional configuration
  #
  # @param policy [Kontena::Registrator::Policy]
  # @param config [nil, Kontena::Registrator::Policy::Config]
  # @raise [ServiceError]
  def create(policy, config = nil)
    config_key = config ? config.to_s : nil

    begin
      service = @class.new(policy, config, **@opts)
    rescue => error
      raise ServiceError, "initialize policy=#{policy} config=#{config}: #{error}"
    else
      logger.info "create policy=#{policy} with config=#{config}: #{service}"
    end


    @services[[policy, config_key]] = service
  end

  # Reload configuration for policy
  #
  # @param policy [Kontena::Registrator::Policy]
  # @param config [nil, Kontena::Etcd::Model]
  # @raise [ServiceError]
  def reload(policy, config = nil)
    service = self[policy, config]

    logger.info "reload policy=#{policy} with config=#{config}: #{config.to_json}"

    begin
      service.reload config
    rescue => error
      raise ServiceError, "reload: #{error}"
    end

    service
  end

  # Stop and remove service for a given Policy and configuration path
  #
  # @param policy [Kontena::Registrator::Policy]
  # @param config_path [nil, String]
  def remove(policy, config_path = nil)
    service = @services[[policy, config_path]]

    logger.info "remove policy=#{policy} with config=#{config_path}: #{service}"

    # XXX TODO: service.remove
    fail
  end

end
