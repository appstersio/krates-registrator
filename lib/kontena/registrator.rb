require 'celluloid'

require 'kontena/logging'
require 'kontena/observable'

module Kontena
  class Registrator < Celluloid::Supervision::Container
    require 'kontena/registrator/docker'
    require 'kontena/registrator/policy'
    require 'kontena/registrator/service'
    require 'kontena/registrator/configuration'
    require 'kontena/registrator/manager'

    include Kontena::Logging

    def initialize(policy_globs: [])
      super

      @policies = Configuration.load_policies(*policy_globs)

      # Persistent Manager state, preserved across Actor restarts
      @services = { }

      # Shared Docker state, updated by the running Docker::Actor, used
      # by other Service actors.
      #
      # If the Docker::Actor restarts, it will simply reload the Docker::State, and
      # continue updating the same Observable.
      #
      # Other Actors do not need to be restarted, they will pick up the refreshed state.
      @docker_observable = Kontena::Observable.new # Docker::State

      # Configuration state
      @configuration_observable = Kontena::Observable.new # Configuration::State

      # Loads service configurations
      supervise type: Configuration, as: :configuration, args: [@configuration_observable, @policies]

      # Manges services from configuration
      supervise type: Manager, as: :manager, args: [@configuration_observable, @services, {docker_observable: @docker_observable}]

      # Updates the global Docker::Actor.observable
      supervise type: Docker::Actor, as: :docker, args: [@docker_observable]
    end
  end
end
