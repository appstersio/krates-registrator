require 'kontena/logging'

# A DSL for generating etcd configuration nodes from Docker containers, with optional configuration
#
# Loading a policy creates a dynamic Context sub-class.
# An instance of the Context can then be used to apply a Docker::State
class Kontena::Registrator::Policy
  include Kontena::Logging

  # Load configuration policies from filesystem path
  #
  # @param path [String] local filesystem path to dir containining *.rb files
  # @return [Array<Kontena::Registrator::Policy>]
  def self.loads(path)
    paths = Dir.glob("#{path}/*.rb")
    policies = paths.map{|path| self.load(path)}
  end

  # Load policy from local filesystem path
  #
  # @param path [String] filesystem path to .rb file
  # @return [Kontena::Registrator::Policy]
  def self.load(path)
    name = File.basename(path, '.*')
    policy = new(name) do |context_class|
      File.open(path, "r") do |file|
        context_class.load(file)
      end
    end

    policy.logger.info "Load policy=#{name} from path=#{path}"

    policy
  end

  # Optional configuration model
  # Also supports etcd
  class Config
    include Kontena::JSON::Model
  end

  # Loading creates a new Context class, and an instance can apply
  class Context
    include Kontena::Logging

    def self.[](sym)
      self.instance_variable_get("@#{sym}")
    end

    # Evaluate .rb DSL
    #
    # @param file [File]
    def self.load(file)
       self.class_eval(file.read, file.path)
    end

    # Declare a Kontena::JSON::Model used to configure this policy's services
    #
    # @param etcd_path [String] Optional Kontena::Etcd::Model#etcd_path schema for loading config from etcd
    # @yield [class] block is evaluated within the new config model class
    def self.config(etcd_path: nil, &block)
      @config_etcd_path = etcd_path

      # policy-specific config class
      @config = Class.new(Config, &block)
      @config.freeze
    end

    attr_accessor :config

    # @param config [Config] optional instance of this class's config model
    def initialize(config = nil)
      @config = config.freeze
    end

    # Register a Docker::Container handler
    #
    # * returning nil is equivalent to returning an empty Hash
    # * nil values are elided
    # * String values are kept as raw strings
    # * Object values are encoded to JSON
    #
    # @param container [Kontena::Registrator::Docker::Container]
    # @return [Hash{String => nil, String, JSON]
    def docker_container(container)
      raise ArgumentError, "Policy does not have any docker_container() method"
    end

    # Legacy compat: register a lambda
    def self.docker_container(proc)
      self.send :define_method, :docker_container, proc
    end

    # Compile a Docker::State into a set of etcd nodes
    #
    # @param state [Kontena::Registrator::Docker::State]
    # @param context [ApplyContext]
    # @return [Hash<String, String>] nodes for Kontena::Etcd::Writer
    def apply(state)
      state_nodes = {}

      state.containers.each do |container|
        # yield or return
        container_nodes = [ ]
        container_nodes << docker_container(container) do |nodes|
          container_nodes << nodes
          nil
        end

        container_nodes.each do |nodes|
          nodes = Kontena::Registrator::Policy.apply_nodes(nodes)

          logger.debug "apply container=#{container}: #{container_nodes}"

          state_nodes.merge!(nodes) do |key, old, new|
            if old == new
              logger.debug "Merge etcd=#{key} node for container=#{container}: #{old.inspect}"

              old
            else
              logger.warn "Overlapping etcd=#{key} node for container=#{container}: #{old.inspect} -> #{new.inspect}"

              # Choose one node deterministically until the overlapping container goes away...
              [old, new].min
            end
          end
        end
      end

      state_nodes
    end

  end

  attr_accessor :name, :context

  def initialize(name, &block)
    @name = name
    @context = Class.new(Context, &block)
    @context.freeze
  end

  def to_s
    "#{@name}"
  end

  # Is the Policy configurable?
  def config?
    return @context[:config] != nil
  end

  # Is the Policy configurable via etcd?
  def config_etcd?
    return @context[:config_etcd_path] != nil
  end

  # Return any Config class that this policy has
  #
  # @return [nil, Class<Config>]
  def config_model
    return @context[:config]
  end

  # Return a Kontena::Etcd::Model Config class for this policy
  #
  # @return [Class<Kontena::Etcd::Model, Config>]
  def config_model_etcd
    config_etcd_path = @context[:config_etcd_path]

    Class.new(config_model) do
      include Kontena::Etcd::Model

      etcd_path config_etcd_path
    end
  end

  # Create instance
  #
  # @param config [Config]
  # @return [Context] instance
  def context(config = nil)
    context = @context.new(config)
    context.logger # memoize before freezing
    context.freeze
  end

  # Normalize policy nodes to etcd nodes
  #
  # @param nodes [Hash{String => nil, String, JSON}]
  # @return nodes [Hash{String => String}]
  def self.apply_nodes(nodes)
    return {} if nodes.nil?
    raise ArgumentError, "Expected Hash, got #{nodes.class}: #{nodes.inspect}" unless nodes.is_a? Hash

    Hash[nodes.map{|key, value|
      case value
      when nil
        next
      when String
        [key, value]
      when true, false, Integer, Float, Array, Hash
        [key, value.to_json]
      else
        raise TypeError, "Invalid value for etcd #{key}: #{value.inspect}"
      end
    }.compact]
  end
end
