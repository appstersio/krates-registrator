require 'celluloid'

require 'kontena/logging'

# Start/stop services from configuration udpates
class Kontena::Registrator::Manager
  include Kontena::Logging
  include Celluloid

  trap_exit :actor_exit

  class ServiceError < StandardError

  end

  class State
    def initialize
      @services = { }
      @configs = { }
    end

    def []=(policy, name, service_config)
      service, config = service_config
      
      @services[[policy, name]] = service
      @configs[service] = [policy, name, config]
    end

    # Update config in-place for restart
    def update(policy, name, config)
      service = @services[[policy, name]]
      @configs[service] = [policy, name, config]
    end

    # Get Service for policy, with optional config
    #
    # @param policy [Kontena::Registrator::Policy]
    # @param config policy configuration object
    # @return [Service]
    def [](policy, name = nil)
      @services[[policy, name]]
    end

    # @yield [policy, name]
    # @yieldparam policy [Kontena::Registrator::Policy]
    # @yieldparam name [String, nil]
    def each(&block)
      @services.each do |key, service|
        policy, name = key
        yield policy, name
      end
    end

    # @param policy [Kontena::Registrator::Policy]
    # @param config_key [String, nil]
    # @return [Service, nil]
    def delete(policy, name = nil)
      service = @services.delete([policy, name])
      @configs.delete(service)

      return service
    end

    # Reverse-lookup parameters for service
    def find_service(service)
      @configs[service]
    end
  end

  def initialize(configuration_observable, state, service_class, service_opts = { }, start: true)
    @configuration_observable = configuration_observable
    @state = state
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
    config_state.each do |policy, name, config|
      logger.debug "apply policy=#{policy} with config=#{name}: #{config.to_json}"

      begin
        if @state[policy, name].nil?
          self.create(policy, name, config)
        elsif config
          self.reload(policy, name, config)
        end
      rescue ServiceError => error
        # skip, omit from @services, and thus retry on next config update
        logger.error error
      end
    end

    # sync down services
    @state.each do |policy, name|
      unless config_state.include? policy, name
        self.remove(policy, name)
      end
    end
  end

  def run
    @configuration_observable.observe do |config_state|
      apply(config_state)
    end
  end

  def actor_exit(actor, reason)
    if params = @state.find_service(actor)
      policy, name, config = params

      logger.error "restart service=#{actor.inspect} with policy=#{policy}:#{name}: #{reason.inspect}"

      self.create(policy, name, config)
    else
      # XXX: do not warn if removed service
      logger.warn "exit actor=#{actor.inspect} for unknown service: #{reason.inspect}"
    end
  end

  # Is the service running?
  #
  # @param policy [Kontena::Registrator::Policy]
  # @param config [nil, Kontena::Registrator::Policy::Config]
  def status(policy, name = nil)
    @state[policy, name]
  end

  # Supervise a new Service for the given Policy and optional configuration
  #
  # @param policy [Kontena::Registrator::Policy]
  # @param config [nil, Kontena::Registrator::Policy::Config]
  # @raise [ServiceError]
  def create(policy, name = nil, config = nil)
    logger.info "create policy=#{policy}:#{name}: #{config.to_json}"

    begin
      service = @class.new(policy, name, config, **@opts)
    rescue => error
      raise ServiceError, "initialize policy=#{policy}:#{name}: #{error}"
    end

    @state[policy, name] = [service, config]

    self.link(service)
  end

  # Reload configuration for policy
  #
  # @param policy [Kontena::Registrator::Policy]
  # @param config [nil, Kontena::Etcd::Model]
  # @raise [ServiceError]
  def reload(policy, name, config)
    service = @state[policy, name]

    logger.info "reload policy=#{policy} with config=#{name}: #{config.to_json}"

    begin
      service.reload config
    rescue => error
      raise ServiceError, "reload: #{error}"
    end

    # update config in state for restart
    @state.update(policy, name, config)

    service
  end

  # Stop and remove service for a given Policy and configuration path
  #
  # @param policy [Kontena::Registrator::Policy]
  # @param config_path [nil, String]
  def remove(policy, name = nil)
    service = @state.delete(policy, name)

    logger.info "remove policy=#{policy} with config=#{name}: #{service}"

    begin
      service.stop
    rescue => error
      raise ServiceError, "stop: #{error}"
    end
  end
end
