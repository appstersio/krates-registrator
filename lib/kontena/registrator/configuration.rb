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
          configs.each do |config_path, config|
            yield policy, config
          end
        else
          yield policy, nil
        end
      end
    end

    # @param policy [Kontena::Registrator::Policy]
    # @param config_key [nil, String]
    # @return [Boolean]
    def include?(policy, config_key = nil)
      return false unless @policy_configs.key? policy

      configs = @policy_configs[policy]

      # XXX: playing around with nils is dangerous
      return true if config_key.nil? && configs.nil?
      return true if config_key && configs && configs.key?(config_key)
      return nil
    end

    # @param policy [Kontena::Registrator::Policy]
    # @param config_key [nil, String]
    # @return [Kontena::Registrator::Policy::Config, nil]
    def [](policy, config_key = nil)
      configs = @policy_configs[policy]

      if configs.nil? && config_key.nil?
        configs
      else
        configs[config_key]
      end
    end
  end

  # Load configuration policies from filesystem path
  def self.load_policies(*globs)
    paths = globs.map{|glob| Dir.glob(glob)}.flatten
    policies = paths.map{|path| Kontena::Registrator::Policy.load(path)}
  end

  # Aggregate configuration state from PolicyConfigurator
  class Configurator
    include Celluloid
    include Kontena::Logging

    # @param policies [Array<Policy>]
    def initialize(observable, policies, start: true)
      @observable = observable
      @policies = policies
      @state = State.new

      logger.debug "initialize with policies=#{@policies}"

      self.start if start
    end

    def start
      @policies.each do |policy|
        if policy.config?
          self.start_policy(policy)
        else
          # apply directly without configuration
          self.apply_policy(policy)
        end
      end
    end

    def start_policy(policy)
      # start a new PolicyConfigurator, which sends us apply_policy
      PolicyConfigurator.supervise args: [policy, Actor.current, :apply_policy]
    end

    # Called by PolicyConfigurator
    #
    # @param policy [Kontena::Registrator::Policy]
    # @param configs [nil, Kontena::Registrator::Policy::Config]
    def apply_policy(policy, configs = nil)
      @state.update! policy, configs

      logger.debug "update with policy=#{policy}: #{configs}"

      @observable.update @state.export
    end
  end

  class PolicyConfigurator
    include Celluloid
    include Kontena::Logging

    def initialize(policy, configurator, message, start: true)
      @policy = policy
      @configurator = configurator
      @message = message

      self.start if start
    end

    def start
      self.async.run
    end

    def run
      logger.info "configure policy=#{@policy} from #{@policy.config_model.etcd_schema}"

      # TODO: trap invalid configuration errors?
      @policy.config_model.watch do |configs|
        logger.debug "configure policy=#{@policy} with #configs=#{configs.size}"

        @configurator.sync @message, @policy, configs.to_h
      end
    end
  end
end
