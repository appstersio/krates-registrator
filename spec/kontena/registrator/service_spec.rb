describe Kontena::Registrator::Service do
  let :docker_observable do
    instance_double(Kontena::Observable)
  end

  let :policy do
    instance_double(Kontena::Registrator::Policy)
  end


  context "with no Docker containers", :celluloid => true, :etcd => true, :docker => true do
    subject do
      described_class.new(docker_observable, policy, start: false)
    end

    let :docker_state do
      docker_state_fixture()
    end

    it "does not write anything to etcd" do
      expect(docker_observable).to receive(:observe).and_yield(docker_state)
      expect(policy).to receive(:call).with(docker_state).and_return({})

      subject.run

      expect(etcd_server).to_not be_modified
    end
  end

  context "with a single Docker container", :celluloid => true, :etcd => true, :docker => true do
    subject do
      described_class.new(docker_observable, policy, start: false)
    end

    let :docker_state do
      docker_state_fixture('test-1')
    end

    before do
      expect(docker_observable).to receive(:observe).and_yield(docker_state)
      expect(policy).to receive(:call).with(docker_state).and_return(
        '/kontena/test/3a61cd3f565b' => '{"host":"172.18.0.2"}',
      )
    end

    it "writes one node to etcd" do
      subject.run

      expect(etcd_server).to be_modified
      expect(etcd_server.nodes).to eq(
        '/kontena/test/3a61cd3f565b' => { 'host' => "172.18.0.2" },
      )
    end

    it "writes and refreshes one node to etcd" do
      subject.run
      subject.refresh

      expect(etcd_server).to be_modified
      expect(etcd_server.nodes).to eq(
        '/kontena/test/3a61cd3f565b' => { 'host' => "172.18.0.2" },
      )
    end
  end
end
