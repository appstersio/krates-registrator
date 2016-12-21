require 'psych'
require 'safe_yaml'

require 'kontena/logging'

module Kontena
  class Registrator
    class Policy
      include Kontena::Logging

      def self.load(path)
        name = File.basename(path)
        policy = new(name)

        File.open(path, "r") do |file|
          policy.load(file)
        end

        policy
      end

      def initialize(name)
        @name = name
      end

      def load(file)
        self.instance_eval(file.read, file.path)
      end

      def docker_container(proc)
        @container_proc = proc
      end

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
