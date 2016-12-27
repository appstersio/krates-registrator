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
