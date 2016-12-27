describe Kontena::Registrator::Manager, :celluloid => true do
  let :state do
    Kontena::Registrator::Manager::State.new
  end

  let :policy do
    instance_double(Kontena::Registrator::Policy, :policy,
      name: 'mock',
      to_s: 'mock',
    )
  end

  let :configuration_observable do
    instance_double(Kontena::Observable)
  end

  let :docker_observable do
    instance_double(Kontena::Observable)
  end

  subject do
    described_class.new(configuration_observable, state, Kontena::Registrator::Service, { docker_observable: docker_observable }, start: false)
  end

  context "For a configurationless policy" do
    let :config_state do
      Kontena::Registrator::Configuration::State.new(
        policy => nil,
      )
    end

    let :service do
      instance_double(Kontena::Registrator::Service)
    end

    it "Creates a single configurationless Service" do
      expect(configuration_observable).to receive(:observe).once.and_yield(config_state)
      expect(subject.wrapped_object).to receive(:create).once.with(policy, nil).and_call_original
      expect(Kontena::Registrator::Service).to receive(:new).and_return(service)
      expect(subject.wrapped_object).to receive(:link).with(service)

      subject.run

      expect(subject.status(policy, nil)).to be service
    end

    it "Does not reload a configurationless Service" do
      expect(configuration_observable).to receive(:observe).once.and_yield(config_state).and_yield(config_state)
      expect(subject.wrapped_object).to receive(:create).once.with(policy, nil).and_call_original
      expect(Kontena::Registrator::Service).to receive(:new).and_return(service)
      expect(subject.wrapped_object).to receive(:link).with(service)
      expect(subject.wrapped_object).to_not receive(:reload)

      subject.run

      expect(subject.status(policy, nil)).to be service
    end
  end

  context "For a single configurable policy" do
    let :config1 do
      instance_double(Kontena::Registrator::Policy::Config, :config1_v1,
        to_s: 'test1',
      )
    end
    let :config1_v2 do
      instance_double(Kontena::Registrator::Policy::Config, :config1_v2,
        to_s: 'test1',
      )
    end
    let :config2 do
      instance_double(Kontena::Registrator::Policy::Config, :config2,
        to_s: 'test2',
      )
    end

    let :service1 do
      instance_double(Kontena::Registrator::Service, :service1)
    end
    let :service2 do
      instance_double(Kontena::Registrator::Service, :service2)
    end

    it "Creates a single configured Service" do
      expect(configuration_observable).to receive(:observe).once
        .and_yield(Kontena::Registrator::Configuration::State.new(
          policy => {
            'test1' => config1,
          },
        ))

      expect(subject.wrapped_object).to receive(:create).once.with(policy, config1).and_call_original
      expect(Kontena::Registrator::Service).to receive(:new).with(policy, config1, docker_observable: docker_observable).and_return(service1)
      expect(subject.wrapped_object).to receive(:link).with(service1)

      subject.run

      expect(subject.status(policy, 'test1')).to be service1
    end

    it "Creates and reloads a single configured Service" do
      expect(configuration_observable).to receive(:observe).once
        .and_yield(Kontena::Registrator::Configuration::State.new(
          policy => {
            'test1' => config1,
          },
        ))
        .and_yield(Kontena::Registrator::Configuration::State.new(
          policy => {
            'test1' => config1_v2,
          },
        ))

      expect(subject.wrapped_object).to receive(:create).once.with(policy, config1).and_call_original
      expect(Kontena::Registrator::Service).to receive(:new).with(policy, config1, docker_observable: docker_observable).and_return(service1)
      expect(subject.wrapped_object).to receive(:link).with(service1)

      expect(subject.wrapped_object).to receive(:reload).once.with(policy, config1_v2).and_call_original
      expect(service1).to receive(:reload).with(config1_v2)

      subject.run

      expect(subject.status(policy, 'test1')).to be service1
    end

    it "Creates a single configured Service, and then creates a second one" do
      expect(configuration_observable).to receive(:observe).once
        .and_yield(Kontena::Registrator::Configuration::State.new(
          policy => {
            'test1' => config1,
          },
        ))
        .and_yield(Kontena::Registrator::Configuration::State.new(
          policy => {
            'test1' => config1,
            'test2' => config2,
          },
        ))

      expect(subject.wrapped_object).to receive(:create).once.with(policy, config1).and_call_original
      expect(Kontena::Registrator::Service).to receive(:new).with(policy, config1, docker_observable: docker_observable).and_return(service1)
      expect(subject.wrapped_object).to receive(:link).with(service1)

      expect(service1).to receive(:reload).with(config1) # config remains the same
      expect(subject.wrapped_object).to receive(:create).once.with(policy, config2).and_call_original
      expect(Kontena::Registrator::Service).to receive(:new).with(policy, config2, docker_observable: docker_observable).and_return(service2)
      expect(subject.wrapped_object).to receive(:link).with(service2)

      subject.run

      expect(subject.status(policy, 'test1')).to be service1
      expect(subject.status(policy, 'test2')).to be service2
    end

    it "Creates a single configured Service, and then replaces it with a second one" do
      expect(configuration_observable).to receive(:observe).once
        .and_yield(Kontena::Registrator::Configuration::State.new(
          policy => {
            'test1' => config1,
          },
        ))
        .and_yield(Kontena::Registrator::Configuration::State.new(
          policy => {
            'test2' => config2,
          },
        ))

      expect(subject.wrapped_object).to receive(:create).once.with(policy, config1).and_call_original
      expect(Kontena::Registrator::Service).to receive(:new).with(policy, config1, docker_observable: docker_observable).and_return(service1)
      expect(subject.wrapped_object).to receive(:link).with(service1)

      expect(subject.wrapped_object).to receive(:create).once.with(policy, config2).and_call_original
      expect(Kontena::Registrator::Service).to receive(:new).with(policy, config2, docker_observable: docker_observable).and_return(service2)
      expect(subject.wrapped_object).to receive(:link).with(service2)

      expect(subject.wrapped_object).to receive(:remove).once.with(policy, 'test1').and_call_original
      expect(service1).to receive(:stop)

      subject.run

      expect(subject.status(policy, 'test1')).to be nil
      expect(subject.status(policy, 'test2')).to be service2
    end
  end

  context "For a service that fails to initialize" do
    let :service_class do
      Class.new do
        include Celluloid

        def initialize(policy, config = nil, asdf: 'quux')
          raise RuntimeError if config.to_s == 'test1'
        end
      end
    end

    subject do
      described_class.new(configuration_observable, state, service_class, start: false)
    end

    let :config1 do
      instance_double(Kontena::Registrator::Policy::Config, :config1_v1,
        to_s: 'test1',
      )
    end
    let :config2 do
      instance_double(Kontena::Registrator::Policy::Config, :config2,
        to_s: 'test2',
      )
    end

    it "Logs the error, and continues to start other services" do
      expect(configuration_observable).to receive(:observe).once
        .and_yield(Kontena::Registrator::Configuration::State.new(
          policy => {
            'test1' => config1,
            'test2' => config2,
          },
        ))

      subject.run

      expect(subject.status(policy, 'test1')).to be_nil
      expect(subject.status(policy, 'test2')).to_not be_nil
    end
  end

  context "For a service that dies" do
    let :service_class do
      Class.new do
        include Celluloid

        def initialize(policy, config = nil, asdf: 'quux')

        end

        def crash
          raise RuntimeError
        end
      end
    end

    subject do
      described_class.new(configuration_observable, state, service_class, start: false)
    end

    let :config1 do
      instance_double(Kontena::Registrator::Policy::Config, :config1_v1,
        to_s: 'test1',
      )
    end

    it "Starts the service" do
      expect(configuration_observable).to receive(:observe).once
        .and_yield(Kontena::Registrator::Configuration::State.new(
          policy => {
            'test1' => config1,
          },
        ))

      subject.run

      service1 = subject.status(policy, 'test1')
      expect(service1).to_not be_nil

      expect(subject.wrapped_object).to receive(:actor_exit).and_call_original
      expect{service1.crash}.to raise_error(RuntimeError)

      sleep 0.1 # XXX

      # restarted
      service2 = subject.status(policy, 'test1')
      expect(service2).to_not be_nil
      expect(service2).to_not be service1
    end

    after do
      # XXX: kill further traps
      #      RSpec::Mocks::OutsideOfExampleError: The use of doubles or partial doubles from rspec-mocks outside of the per-test lifecycle is not supported.
      subject.terminate
    end
  end
end
