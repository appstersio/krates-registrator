require 'kontena/logging'

# A schema for selecting Docker containers and registering etcd configuration nodes
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
    policy = new(name)

    File.open(path, "r") do |file|
      policy.load(file)
    end

    policy.logger.info "Load policy=#{name} from path=#{path}"

    policy
  end

  class Config
    include Kontena::Etcd::Model
    include Kontena::JSON::Model

    def to_s
      "#{etcd_key}"
    end
  end

  attr_accessor :name, :context

  def initialize(name)
    @name = name
    @context = LoadContext.new
  end

  def to_s
    "#{@name}"
  end

  # Evaluate .rb DSL
  #
  # @param file [File]
  def load(file)
     @context.instance_eval(file.read, file.path)
     @context.freeze # XXX: deep-freeze?
  end

  # Load-time evaluation context for DSL
  class LoadContext
    def [](sym)
      instance_variable_get("@#{sym}")
    end

    # Declare a Kontena::Etcd::Model used to configure policy services
    def config(&block)
      # policy-specific config class
      @config = Class.new(Config)
      @config.instance_eval(&block)
    end

    # Register a Docker::Container handler
    #
    # * returning nil is equivalent to returning an empty Hash
    # * nil values are elided
    # * String values are kept as raw strings
    # * Object values are encoded to JSON
    #
    # @param proc [Proc] Kontena::Registrator::Docker::Container -> Hash{String => nil, String, JSON>
    def docker_container(proc)
      @docker_container = proc
    end
  end

  # Is the Policy configurable?
  def config?
    return @context[:config] != nil
  end

  # Return any Config class that this policy has
  #
  # @return [nil, Class<Config>]
  def config_model
    return @context[:config]
  end

  # Normalize policy nodes to etcd nodes
  #
  # @param nodes [Hash{String => nil, String, JSON}]
  # @return nodes [Hash{String => String}]
  def apply_nodes(nodes)
    return {} if nodes.nil?

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
    }]
  end

  # Compile a Docker::State into a set of etcd nodes
  #
  # @param state [Kontena::Registrator::Docker::State]
  # @param context [ApplyContext]
  # @return [Hash<String, String>] nodes for Kontena::Etcd::Writer
  def apply(state, context)
    nodes = {}

    state.containers.each do |container|
      container_nodes = apply_nodes(context.instance_exec(container, &@context[:docker_container]))

      logger.debug "apply container=#{container}: #{container_nodes}"

      nodes.merge!(container_nodes) do |key, old, new|
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

    nodes
  end

  # @param config [Config]
  # @return [ApplyContext]
  def apply_context(config = nil)
    ApplyContext.new(config)
  end

  # Apply-time evaluation context for DSL procs
  # One policy may have multiple Services, each with a different ApplyContext...
  #
  # @attr config [Config, nil] instance of Policy#config_model class
  class ApplyContext
    attr_reader :config

    def initialize(config = nil)
      @config = config
      @config.freeze

      self.freeze
    end
  end
end
