describe Kontena::Registrator::Configuration::State do
  context "For a single configurationless policy" do
    let :policy do
      instance_double(Kontena::Registrator::Policy,
        name: 'mock',
      )
    end

    subject do
      described_class.new(
        policy => nil,
      )
    end

    it "includes that policy without a config" do
      expect(subject.include? policy).to be_truthy
      expect(subject.include? policy, nil).to be_truthy
    end

    it "does not include that policy with a config" do
      expect(subject.include? policy, "test").to_not be_truthy
    end
  end

  context "For a single configured policy" do
    let :policy do
      instance_double(Kontena::Registrator::Policy,
        name: 'mock',
      )
    end

    let :config do
      instance_double(Kontena::Registrator::Policy::Config)
    end

    subject do
      described_class.new(
        policy => {
          'test' => config,
        },
      )
    end

    describe '#include?' do
      it "does not include that policy without a config" do
        expect(subject.include? policy).to be_falsey
        expect(subject.include? policy, nil).to be_falsey
      end
      it "includes that policy with the config" do
        expect(subject.include? policy, "test").to be_truthy
      end
      it "does not include that policy with a different config" do
        expect(subject.include? policy, "test2").to_not be_truthy
      end
    end
  end
end

describe Kontena::Registrator::Configuration::Local do
  context "For a single policy without configuration", :fixtures => true do
    let :test_policy do
      Kontena::Registrator::Policy.load(fixture_path(:policy, 'test.rb'))
    end
    let :skydns_policy do
      Kontena::Registrator::Policy.load(fixture_path(:policy, 'skydns.rb'))
    end

    let :policies do
      [test_policy, skydns_policy]
    end

    let :observable do
      instance_double(Kontena::Observable)
    end

    subject do
      described_class.new(observable, policies)
    end

    it "Loads both configurationless and configured policies" do
      state = nil

      expect(observable).to receive(:update) { |update_state| state = update_state }
      subject.load(fixture_path(:services))

      expect(state).to_not be_nil
      expect(state.include? test_policy).to be_truthy
      expect(state.include? skydns_policy, '/kontena/registrator/services/skydns/kontena-local').to be_truthy
    end
  end
end
