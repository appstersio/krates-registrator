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
end
