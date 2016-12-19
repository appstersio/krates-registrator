require 'psych'
require 'safe_yaml'

module Kontena::Registrator
  class Policy
    include Kontena::Logging

    def self.load(path)
      name = File.basename(path)

      # XXX: broken YAML tags
      data = SafeYAML.load(File.read(path), path,
        custom_initializers: {
          'proc'  => lambda { STDERR.puts "Got !proc" },
        },
        raise_on_unknown_tag: true,
      )
      data = Hash[data.map{|key, value| [key.to_sym, value] }]

      new(name, **data)
    end

    def initialize(name, env: {}, where: [], let: {}, etcd: {})
      @name = name
      @env = Hash[env.map{|key, value| [key.to_sym, value]}]
      @where = where
      @let = let
      @etcd = etcd

      logger.debug self.inspect
    end

    def context_for_container(container)
      context = Eval::Context.new(container: container, **@env)

      @where.each do |expr|
        if value = context.eval(expr)
          logger.debug "container=#{container} where=#{expr} match value=#{value}"
        else
          logger.debug "container=#{container} where=#{expr} skip value=#{value}"
          return nil
        end
      end

      @let.each_pair do |sym, expr|
        context.set(sym, expr)
      end

      logger.debug "container=#{container}: #{context}"

      return context
    end

    def etcd_for_container(container)
      if context = context_for_container(container)
        context.eval(@etcd).each do |path, value|
          logger.debug "container=#{container} etcd=#{path} value=#{value.inspect}"

          yield path, value if path && value
        end
      end
    end
  end
end
