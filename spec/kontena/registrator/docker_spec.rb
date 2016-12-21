describe Kontena::Registrator::Docker::Container, :docker => true do
  context "for the test-1 container" do
    subject { docker_container_fixture('test-1') }

    it "has an ID" do
      expect(subject.id).to eq '10c1de7f15b5596f53b7e8ef63d2f16d19da540ab34a402701c81633d090685d'
    end

    it "has a name" do
      expect(subject.name).to eq 'test-1'
    end

    it "has a hostname" do
      expect(subject.hostname).to eq 'test-1'
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

describe Kontena::Registrator::Docker::Actor, celluloid: true do
  let :observable do
    Kontena::Observable.new
  end

  subject do
    described_class.new(observable, start: false)
  end

  context "Without any running Docker containers", :docker => true do
    before do
      stub_docker('containers/json', all: true) { [] }
    end

    describe '#sync' do
      it "Updates an empty state" do
        expect(observable).to receive(:update) { |state|
          expect(state.containers.to_a).to be_empty
        }

        subject.sync_state
      end
    end
  end

  context "With one running Docker container, and a second one created", :docker => true do
    before do
      stub_docker('containers/json', all: true) { docker_fixture(:list, 'test-1') }
      stub_docker('containers/10c1de7f15b5596f53b7e8ef63d2f16d19da540ab34a402701c81633d090685d/json') { docker_fixture(:inspect, 'test-1') }
      stub_docker('events') {
        docker_fixture(:events, 'test-2_01-create')
      }
      stub_docker('containers/1d82bdcf1715d2717e788a721ce3a95e61d8d6e99f0dab3d57f929bb601d1004/json') { docker_fixture(:inspect, 'test-2') }
    end

    it "Updates state from one to two containers" do
      expect(observable).to receive(:update).once { |state|
        expect(state.containers.map{|container| container.name}).to eq ['test-1']
      }
      expect(observable).to receive(:update).once { |state|
        expect(state.containers.map{|container| container.name}).to eq ['test-1', 'test-2']
      }

      subject.sync_state
      subject.run
    end
  end

  context "With two running Docker containers, and the second one is destroyed", :docker => true do
    before do
      stub_docker('containers/json', all: true) { docker_fixtures(:list, 'test-1', 'test-2') }
      stub_docker('containers/10c1de7f15b5596f53b7e8ef63d2f16d19da540ab34a402701c81633d090685d/json') { docker_fixture(:inspect, 'test-1') }
      stub_docker('containers/1d82bdcf1715d2717e788a721ce3a95e61d8d6e99f0dab3d57f929bb601d1004/json') { docker_fixture(:inspect, 'test-2') }
      stub_docker('events') {
        docker_fixture(:events, 'test-2_20-destroy')
      }
    end

    it "Updates state from two to one containers" do
      expect(observable).to receive(:update).once { |state|
        expect(state.containers.map{|container| container.name}).to eq ['test-1', 'test-2']
      }
      expect(observable).to receive(:update).once { |state|
        expect(state.containers.map{|container| container.name}).to eq ['test-1']
      }

      subject.sync_state
      subject.run
    end
  end
end
