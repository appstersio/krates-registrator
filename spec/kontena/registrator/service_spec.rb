describe Kontena::Registrator::Service do
  let :docker_observable do
    instance_double(Kontena::Observable)
  end

  let :policy do
    instance_double(Kontena::Registrator::Policy)
  end

  context "for a simple policy with no config" do
    let :apply_context do
      instance_double(Kontena::Registrator::Policy::ApplyContext)
    end

    subject do
      allow(policy).to receive(:apply_context).with(nil).and_return(apply_context)

      described_class.new(policy, nil, docker_observable: docker_observable, start: false)
    end

    context "with no Docker containers", :celluloid => true, :etcd => true, :docker => true do
      let :docker_state do
        docker_state_fixture()
      end

      it "does not write anything to etcd" do
        expect(docker_observable).to receive(:observe).and_yield(docker_state)
        expect(policy).to receive(:apply).with(docker_state, apply_context).and_return({})

        subject.run

        expect(etcd_server).to_not be_modified
      end
    end

    context "with a single Docker container", :celluloid => true, :etcd => true, :docker => true do
      let :docker_state do
        docker_state_fixture('test-1')
      end

      before do
        expect(docker_observable).to receive(:observe).once.and_yield(docker_state)
        expect(policy).to receive(:apply).with(docker_state, apply_context).and_return(
          '/kontena/test/test-1' => '{"host":"172.18.0.2"}',
        )
      end

      it "writes one node to etcd" do
        subject.run

        expect(etcd_server).to be_modified
        expect(etcd_server.nodes).to eq(
          '/kontena/test/test-1' => { 'host' => "172.18.0.2" },
        )
      end

      it "writes and refreshes one node to etcd" do
        subject.run
        subject.refresh

        expect(etcd_server).to be_modified
        expect(etcd_server.nodes).to eq(
          '/kontena/test/test-1' => { 'host' => "172.18.0.2" },
        )
      end
    end

    context "with a two Docker containers, where one goes away", :celluloid => true, :etcd => true, :docker => true do
      let :docker_state1 do
        docker_state_fixture('test-1', 'test-2')
      end
      let :docker_state2 do
        docker_state_fixture('test-1')
      end

      before do
        expect(docker_observable).to receive(:observe).and_yield(docker_state1).and_yield(docker_state2)
        expect(policy).to receive(:apply).with(docker_state1, apply_context).and_return(
          '/kontena/test/test-1' => '{"host":"172.18.0.2"}',
          '/kontena/test/test-2' => '{"host":"172.18.0.3"}',
        )
        expect(policy).to receive(:apply).with(docker_state2, apply_context).and_return(
          '/kontena/test/test-1' => '{"host":"172.18.0.2"}',
        )
      end

      it "writes both nodes to etcd, and then deletes the second one" do
        subject.run

        expect(etcd_server).to be_modified
        expect(etcd_server.logs).to eq [
          [:set, '/kontena/test/test-1'],
          [:set, '/kontena/test/test-2'],
          [:delete, '/kontena/test/test-2'],
        ]
        expect(etcd_server.nodes).to eq(
          '/kontena/test/test-1' => { 'host' => "172.18.0.2" },
        )
      end
    end
  end

  context "for a policy with a configuration", :celluloid => true, :etcd => true do
    let :config do
      instance_double(Kontena::Registrator::Policy::Config)
    end

    let :apply_context do
      instance_double(Kontena::Registrator::Policy::ApplyContext)
    end

    subject do
      allow(policy).to receive(:apply_context).with(config).and_return(apply_context)

      described_class.new(policy, config, docker_observable: docker_observable, start: false)
    end

    context "for a single Docker container", :docker => true do
      let :docker_state do
        docker_state_fixture('test-1')
      end

      it "writes one node to etcd" do
        expect(docker_observable).to receive(:observe).once.and_yield(docker_state)
        expect(policy).to receive(:apply).with(docker_state, apply_context).and_return(
          '/kontena/test/test-1' => '{"host":"172.18.0.2"}',
        )

        subject.run

        expect(etcd_server).to be_modified
        expect(etcd_server.nodes).to eq(
          '/kontena/test/test-1' => { 'host' => "172.18.0.2" },
        )
      end
    end

    context "for a single Docker container that gets reconfigured", :docker => true do
      let :config2 do
        instance_double(Kontena::Registrator::Policy::Config)
      end

      let :apply_context2 do
        instance_double(Kontena::Registrator::Policy::ApplyContext)
      end

      let :docker_state do
        docker_state_fixture('test-1')
      end

      it "writes one node to etcd" do
        expect(policy).to receive(:apply_context).with(config2).and_return(apply_context2)
        expect(policy).to receive(:apply).with(docker_state, apply_context).and_return(
          '/kontena/test/test-1' => '{"host":"172.18.0.2"}',
        )
        expect(policy).to receive(:apply).with(docker_state, apply_context2).and_return(
          '/kontena/test2/test-1' => '{"host":"172.18.0.2"}',
        )

        expect(docker_observable).to receive(:observe).once.and_yield(docker_state)
        expect(docker_observable).to receive(:get).once.and_return(docker_state)

        subject.run # once
        subject.reload config2

        expect(etcd_server).to be_modified
        expect(etcd_server.logs).to eq [
          [:set, '/kontena/test/test-1'],
          [:set, '/kontena/test2/test-1'],
          [:delete, '/kontena/test/test-1'],
        ]
        expect(etcd_server.nodes).to eq(
          '/kontena/test2/test-1' => { 'host' => "172.18.0.2" },
        )
      end
    end
  end
end
