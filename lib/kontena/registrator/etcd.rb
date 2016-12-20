require 'kontena/logging'
require 'kontena/etcd/client'

module Kontena::Registrator::Etcd
  class Writer
    include Kontena::Logging

    def initialize
      @nodes = { }
      @client = Kontena::Etcd::Client.new

      logger.info "Connected to etcd=#{@client.uri} with version=#{@client.version}"
    end

    # Update set of path => value nodes to etcd
    #
    # XXX: set with TTL + refresh to expire nodes on restart?
    def update(nodes)
      nodes.each_pair do |key, value|
        if value != @nodes[key]
          @client.set(key, value: value)
        end
      end

      @nodes.each do |key, value|
        if !nodes[key]
          @client.delete(key)
        end
      end

      @nodes = nodes
    end
  end
end
