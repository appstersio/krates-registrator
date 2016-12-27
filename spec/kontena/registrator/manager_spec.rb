describe Kontena::Registrator::Manager, :celluloid => true do
  let :policy do
    instance_double(Kontena::Registrator::Policy,
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
    described_class.new(configuration_observable, { }, { docker_observable: docker_observable }, start: false)
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
      expect(Kontena::Registrator::Service).to receive(:new_link).and_return(service)

      subject.run

      expect(subject.status(policy, nil)).to be service
    end

    it "Does not reload a configurationless Service" do
      expect(configuration_observable).to receive(:observe).once.and_yield(config_state).and_yield(config_state)
      expect(subject.wrapped_object).to receive(:create).once.with(policy, nil).and_call_original
      expect(Kontena::Registrator::Service).to receive(:new_link).and_return(service)
      expect(subject.wrapped_object).to_not receive(:reload)

      subject.run

      expect(subject.status(policy, nil)).to be service
    end
  end

  context "For a single configurable policy" do
    let :config do
      instance_double(Kontena::Registrator::Policy::Config,
        to_s: 'test',
      )
    end

    let :config_state do
      Kontena::Registrator::Configuration::State.new(
        policy => {
          'test' => config,
        },
      )
    end

    let :service do
      instance_double(Kontena::Registrator::Service)
    end

    it "Creates a single configured Service" do
      expect(configuration_observable).to receive(:observe).once.and_yield(config_state)
      expect(subject.wrapped_object).to receive(:create).once.with(policy, config).and_call_original
      expect(Kontena::Registrator::Service).to receive(:new_link).with(policy, config, docker_observable: docker_observable).and_return(service)

      subject.run

      expect(subject.status(policy, 'test')).to be service
    end
  end


end
