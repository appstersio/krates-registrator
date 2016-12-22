require 'kontena/logging'

# A schema for selecting Docker containers and registering etcd configuration nodes
class Kontena::Registrator::Policy
  include Kontena::Logging

  # @param path [String] filesystem path to .rb file
  def self.load(path)
    name = File.basename(path)
    policy = new(name)

    File.open(path, "r") do |file|
      policy.load(file)
    end

    policy
  end

  attr_accessor :name, :context

  def initialize(name)
    @name = name
    @context = Context.new
  end

  # Evaluate .rb DSL
  #
  # @param file [File]
  def load(file)
     @context.instance_eval(file.read, file.path)
  end

  # Evaluation context for DSL
  class Context
    def [](sym)
      instance_variable_get("@#{sym}")
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
  # @return [Hash<String, String>] nodes for Kontena::Etcd::Writer
  def apply(state)
    nodes = {}

    state.containers.each do |container|
      nodes.merge! apply_nodes @context[:docker_container].call(container)
    end

    nodes
  end
end
