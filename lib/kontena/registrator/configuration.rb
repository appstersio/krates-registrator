require 'celluloid'

require 'kontena/logging'
require 'kontena/etcd'

# Configure dynamic Services from local Policy classes + etcd configurations
class Kontena::Registrator::Configuration
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

  include Celluloid
  include Kontena::Logging

  # Load configuration policies from filesystem path
  def self.load_policies(*globs)
    paths = globs.map{|glob| Dir.glob(glob)}.flatten
    policies = paths.map{|path| Kontena::Registrator::Policy.load(path)}
    policies = Hash[policies.map { |policy| [policy.name, policy] }]
  end

  # @param policies [Hash{String => Policy}]
  def initialize(observable, policies, start: true)
    @observable = observable
    @policies = policies
    @state = State.new

    logger.debug "initialize with policies=#{@policies.keys}"

    self.start if start
  end

  def start
    @policies.each do |name, policy|
      if policy.config?
        self.async.run_policy(policy)
      else
        self.apply_policy(policy)
      end
    end
  end

  def run_policy(policy)
    logger.debug "configure policy=#{policy}..."

    # XXX: this operation will block the Actor on the etcd watch
    # TODO: trap invalid configuration errors?
    policy.config_model.watch do |configs|
      logger.debug "configure policy=#{policy} with #configs=#{configs.size}"

      apply_policy(policy, configs.to_h)
    end
  end

  def apply_policy(policy, configs = nil)
    @state.update! policy, configs

    @observable.update @state.export
  end
end
