require 'kontena/logging'

module Kontena
  class Registrator
    # A schema for selecting Docker containers and registering etcd configuration nodes
    class Policy
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

      attr_accessor :name

      def initialize(name)
        @name = name
      end

      # Evaluate .rb DSL
      #
      # @param file [File]
      def load(file)
        self.instance_eval(file.read, file.path)
      end

      # Register a Docker::Container handler
      #
      # @param proc [Proc] Kontena::Registrator::Docker::Container -> Hash<String, String>
      def docker_container(proc)
        @container_proc = proc
      end

      # Compile a Docker::State into a set of etcd nodes
      #
      # @param state [Kontena::Registrator::Docker::State]
      # @return [Hash<String, String>] nodes for Kontena::Etcd::Writer
      def call(state)
        nodes = {}

        state.containers.each do |container|
          ret = @container_proc.call(container)
          nodes.merge! ret if ret
        end

        nodes
      end
    end
  end
end
