require 'celluloid'

require 'kontena/logging'
require 'kontena/etcd'

# Configure dynamic Services from local Policy classes + etcd configurations
module Kontena::Registrator::Configuration
  class State
    def initialize(policy_configs = { })
      @policy_configs = policy_configs
    end

    def update!(policy, configs)
      configs.freeze

      @policy_configs[policy] = configs
    end

    # Clone and freeze
    def export
      policy_configs = @policy_configs.clone
      policy_configs.freeze

      state = self.class.new(policy_configs)
      state.freeze
      state
    end

    include Enumerable

    # @yield [policy, config]
    # @yieldparam policy [Kontena::Registrator::Policy]
    # @yieldparam config [nil, Object]
    def each
      @policy_configs.each do |policy, configs|
        if configs
          configs.each do |name, config|
            yield policy, name, config
          end
        else
          yield policy, nil
        end
      end
    end

    # @param policy [Kontena::Registrator::Policy]
    # @param config_key [nil, String]
    # @return [Boolean]
    def include?(policy, name = nil)
      return false unless @policy_configs.key? policy

      configs = @policy_configs[policy]

      # XXX: playing around with nils is dangerous
      return true if name.nil? && configs.nil?
      return true if name && configs && configs.key?(name)
      return nil
    end

    # @param policy [Kontena::Registrator::Policy]
    # @param config_key [nil, String]
    # @return [Kontena::Registrator::Policy::Config, nil]
    def [](policy, name = nil)
      configs = @policy_configs[policy]

      if configs.nil? && name.nil?
        configs
      else
        configs[name]
      end
    end
  end

  # Load local policy service configurations from local filesystem
  class Local
    include Kontena::Logging

    # @param path [String] local filesystem path to dir containing :policy/:service.json files
    def initialize(path)
      @path = path
    end

    # Load configurations for policy from filesystem path
    #
    # @param policy [Kontena::Registrator::Policy]
    # @return [Hash{String => Array<Kontena::Registrator::Policy::Config>]}]
    def load_policy(policy)
      return {} unless @path

      path = File.join(@path, policy.name)
      paths = Dir.glob("#{path}/*.json")

      Hash[paths.map { |path|
        name = File.basename(path, ".json")

        config = policy.config_model.new

        File.open(path) do |file|
          # TODO: error with file path
          config.from_json! file.read
        end

        config.freeze

        logger.info "load policy=#{policy} name=#{name} from path=#{path}: #{config.to_json}"

        [name, config]
      }]
    end

    # Load policy configs from @path and return State
    #
    # @param policies [Array<Kontena::Registrator::Policy>]
    # @return [Kontena::Registartor::Configuration::State]
    def load(policies)
      state = State.new

      policies.each do |policy|
        if policy.config?
          configs = load_policy(policy)

          state.update! policy, configs
        else
          logger.info "load policy=#{policy} without config"

          state.update! policy, nil
        end
      end

      state
    end
  end

  # Aggregate configuration state from dynamic PolicyConfigurator configs
  class Configurator
    include Celluloid
    include Kontena::Logging

    # @param policies [Array<Policy>]
    def initialize(observable, policies, local_configuration, start: true)
      @observable = observable
      @policies = policies
      @local_configuration = local_configuration
      @state = State.new

      logger.debug "initialize with policies=#{@policies}"

      self.start if start
    end

    def start
      @policies.each do |policy|
        if policy.config_etcd?
          # dynamic configurable policy
          self.start_policy(policy)
        elsif policy.config?
          # static configurable policy
          self.load_policy(policy)
        else
          # static configurationless policy
          self.apply_policy(policy)
        end
      end

      self.update!
    end

    # Start a dynamically configurable policy
    def start_policy(policy)
      # start a new PolicyConfigurator, which sends us apply_policy
      PolicyConfigurator.supervise args: [policy, Actor.current, :apply_policy]
    end

    # Load a statically configurable policy
    def load_policy(policy)
      apply_policy policy, @local_configuration.load_policy(policy)
    end

    # Called by PolicyConfigurator
    #
    # @param policy [Kontena::Registrator::Policy]
    # @param configs [nil, Kontena::Registrator::Policy::Config]
    def apply_policy(policy, configs = nil)
      @state.update! policy, configs

      logger.debug "update with policy=#{policy}: #{configs}"

      update!
    end

    def update!
      @observable.update @state.export
    end
  end

  class PolicyConfigurator
    include Celluloid
    include Kontena::Logging

    def initialize(policy, configurator, message, start: true)
      @policy = policy
      @etcd_model = policy.config_model_etcd
      @configurator = configurator
      @message = message

      self.start if start
    end

    def start
      self.async.run
    end

    def run
      logger.info "configure policy=#{@policy} from etcd=#{@etcd_model.etcd_schema}"

      # TODO: trap invalid configuration errors?
      @etcd_model.watch do |configs|
        logger.debug "configure policy=#{@policy} with #configs=#{configs.size}"

        @configurator.sync @message, @policy, configs.to_h
      end
    end
  end
end
