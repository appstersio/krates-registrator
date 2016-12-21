describe Kontena::Registrator::Docker::Container, :docker => true do
  context "for the test-1 container" do
    subject { docker_container_fixture('test-1') }

    it "has an ID" do
      expect(subject.id).to eq '3a61cd3f565ba220a70d4331a3724f7423b64336b343315816f90f8f4d99af32'
    end

    it "has a name" do
      expect(subject.name).to eq 'test-1'
    end

    it "has a hostname" do
      expect(subject.hostname).to eq '3a61cd3f565b'
    end
  end
end

describe Kontena::Registrator::Docker::State, :docker => true do
  context "for the test-1 and test-2 containers" do
    subject { docker_state_fixture('test-1', 'test-2') }

    it "has both containers" do
      expect(subject.containers.map{|container| container.name}.sort).to eq ['test-1', 'test-2']
    end
  end
end

describe Kontena::Registrator::Docker::Actor do
  context "Without any running Docker containers", celluloid: true do
    before do
      allow(Docker::Container).to receive(:all).and_return([])
      allow(Docker::Event).to receive(:stream)
    end

    it "Pushes an empty state" do
      actor = described_class.new

      described_class.observable.observe do |state|
        expect(state.containers.to_a).to be_empty
        break
      end
    end
  end
end
