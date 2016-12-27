describe Kontena::Registrator::Manager, :celluloid => true do
  let :policy do
    instance_double(Kontena::Registrator::Policy,
      name: 'mock',
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
      expect(Kontena::Registrator::Service).to receive(:new_link).and_return(service)
      #expect(subject).to receive(:create).with(policy, nil).and_call_original

      subject.run

      expect(subject.status(policy, nil)).to be service
    end
  end
end
