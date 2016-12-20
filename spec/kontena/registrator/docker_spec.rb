require 'kontena/registrator'
require 'kontena/registrator/docker'

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
