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

    def initialize(policies_path: , services_path: [], etcd_endpoint: nil)
      super

      # Load policy DSL files
      @policies = Policy.loads(policies_path)

      local_configuration = Configuration::Local.new(services_path)

      # Load configuration
      @configuration_observable = Kontena::Observable.new # Configuration::State

      if etcd_endpoint
        # Load dynamic etcd configuration
        supervise type: Configuration::Configurator, as: :configuration, args: [@configuration_observable, @policies, local_configuration]
      else
        # Load static local configuration
        @configuration_observable.update local_configuration.load(@policies).export
      end

      # Shared Docker state, updated by the running Docker::Actor, used
      # by other Service actors.
      #
      # If the Docker::Actor restarts, it will simply reload the Docker::State, and
      # continue updating the same Observable.
      #
      # Other Actors do not need to be restarted, they will pick up the refreshed state.
      @docker_observable = Kontena::Observable.new # Docker::State

      # Updates the global Docker::Actor.observable
      supervise type: Docker::Actor, as: :docker, args: [@docker_observable]

      # Persistent Manager state, preserved across Actor restarts
      @manager_state = Manager::State.new

      # Manges services from configuration
      supervise type: Manager, as: :manager, args: [@configuration_observable, @manager_state, Kontena::Registrator::Service, {docker_observable: @docker_observable}, { }]
    end
  end
end
