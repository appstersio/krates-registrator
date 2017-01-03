describe Kontena::Registrator::Policy do
  context "for a sample SkyDNS policy", :docker => true do
    subject do
      policy = described_class.new(:skydns)
      policy.context.docker_container -> (container) {
        {
          "/skydns/local/skydns/#{container.hostname}" => { host: container['NetworkSettings', 'IPAddress'] },
        }
      }
      policy
    end

    let :docker_state do
      docker_state_fixture('test-1', 'test-2')
    end

    let :apply_context do
      subject.apply_context()
    end

    it "returns etcd nodes for two containers" do
      expect(subject.apply(docker_state, apply_context)).to eq(
        '/skydns/local/skydns/test-1' => '{"host":"172.18.0.2"}',
        '/skydns/local/skydns/test-2' => '{"host":"172.18.0.3"}',
      )
    end
  end

  context "for a policy that produces overlapping nodes", :docker => true do
    subject do
      policy = described_class.new(:skydns)
      policy.context.docker_container -> (container) {
        {
          "/kontena/test" => { hostname: container.hostname },
        }
      }
      policy
    end

    context "for two different node values" do
      let :docker_state do
        docker_state_fixture('test-1', 'test-2')
      end

      let :apply_context do
        subject.apply_context()
      end

      it "logs a warning and returns the smaller of the two nodes" do
        expect(subject.logger).to receive(:warn)
        expect(subject.apply(docker_state, apply_context)).to eq(
          '/kontena/test' => '{"hostname":"test-1"}',
        )
      end
    end

    context "for two identical node values" do
      let :docker_state do
        docker_state_fixture('test-1', 'test-1')
      end

      let :apply_context do
        subject.apply_context()
      end

      it "returns that node" do
        expect(subject.logger).to_not receive(:warn)
        expect(subject.apply(docker_state, apply_context)).to eq(
          '/kontena/test' => '{"hostname":"test-1"}',
        )
      end
    end
  end

  context "for a policy that attempts to mutate values", :docker => true do
    subject do
      policy = described_class.new(:skydns)
      policy.context.config do
        def test_class_mutate
          self.class.include Comparable
        end
        def test_instance_mutate
          @foo = 'bar'
        end
      end
      policy
    end

    let :config_class do
      subject.context[:config]
    end

    let :policy_config do
      subject.config_model.new()
    end

    let :apply_context do
      subject.apply_context(policy_config)
    end

    let :docker_state do
      docker_state_fixture('test-1')
    end

    it "raises on config class mutation" do
      subject.context.docker_container -> (container) {
        config.test_class_mutate
      }

      expect{subject.apply(docker_state, apply_context)}.to raise_error(RuntimeError, /can't modify frozen/)
    end

    it "raises on config instance mutation" do
      subject.context.docker_container -> (container) {
        config.test_instance_mutate
      }

      expect{subject.apply(docker_state, apply_context)}.to raise_error(RuntimeError, /can't modify frozen/)
    end

    it "raises on apply context mutation" do
      subject.context.docker_container -> (container) {
        @config = nil
      }

      expect{subject.apply(docker_state, apply_context)}.to raise_error(RuntimeError, /can't modify frozen/)
    end
  end

  context "for a configurable SkyDNS policy", :docker => true do
    subject do
      policy = described_class.new(:skydns)
      policy.context.config etcd_path: '/kontena/registrator/services/skydns/:service' do
        json_attr :domain, default: 'skydns.local'
        json_attr :network, default: 'bridge'
      end
      policy.context.docker_container -> (container) {
        if ip = container['NetworkSettings', 'Networks', config.network, 'IPAddress']
          {
            "/skydns/#{config.domain.split('.').reverse.join('/')}/#{container.hostname}" => { host: ip },
          }
        end
      }
      policy
    end

    let :docker_state do
      docker_state_fixture('test-1', 'test-2')
    end

    context "for a local config" do
      let :policy_config do
        subject.config_model.new(domain: 'kontena.local')
      end

      let :apply_context do
        subject.apply_context(policy_config)
      end

      it "returns etcd nodes for two containers" do
        expect(policy_config.class.included_modules).to include(Kontena::JSON::Model)
        expect(policy_config.domain).to eq 'kontena.local'
        expect(policy_config.network).to eq 'bridge'

        expect(subject.apply(docker_state, apply_context)).to eq(
          '/skydns/local/kontena/test-1' => '{"host":"172.18.0.2"}',
          '/skydns/local/kontena/test-2' => '{"host":"172.18.0.3"}',
        )
      end
    end

    context "for an etcd config", :etcd => true do
      let :config_model do
        subject.config_model_etcd
      end

      before do
        etcd_server.load!(
          '/kontena/registrator/services/skydns/test' => { 'domain' => 'kontena.local' },
        )
      end

      let :policy_config do
          config_model.get('test')
      end

      let :apply_context do
        apply_context = subject.apply_context(policy_config)
      end

      it "loads a config from etcd" do
        expect{policy_config}.to_not raise_error
        expect(policy_config).to have_attributes(service: 'test', domain: 'kontena.local', network: 'bridge')
      end

      it "returns etcd nodes for two containers" do
        expect(config_model.included_modules).to include(Kontena::Etcd::Model, Kontena::JSON::Model)
        expect(policy_config.domain).to eq 'kontena.local'
        expect(policy_config.network).to eq 'bridge'

        expect(subject.apply(docker_state, apply_context)).to eq(
          '/skydns/local/kontena/test-1' => '{"host":"172.18.0.2"}',
          '/skydns/local/kontena/test-2' => '{"host":"172.18.0.3"}',
        )
      end
    end
  end

  describe '#load' do
    context "For a simple test policy", :fixtures => true, :docker => true do
      let :docker_state do
        docker_state_fixture('test-1', 'test-2')
      end

      let :apply_context do
        subject.apply_context()
      end

      subject do
        described_class.load(fixture_path(:policy, 'test.rb'))
      end

      it "Loads a policy .rb file" do
        expect(subject.name).to eq 'test'
        expect(subject).to_not be_config
      end

      it "returns etcd nodes for two containers" do
        expect(subject.apply(docker_state, apply_context)).to eq(
          '/kontena/test/test-1' => "172.18.0.2",
          '/kontena/test/test-2' => "172.18.0.3",
        )
      end
    end

    context "For a bad policy that tries to mutate the load context", :fixtures => true, :docker => true do
      let :docker_state do
        docker_state_fixture('test-1', 'test-2')
      end

      let :apply_context do
        subject.apply_context()
      end

      subject do
        described_class.load(fixture_path(:policy_bad, 'mutate-loadcontext.rb'))
      end

      it "fails to apply" do
        expect{subject.apply(docker_state, apply_context)}.to raise_error(RuntimeError, /can't modify frozen #<Class:#<Kontena::Registrator::Policy::LoadContext:/)
      end
    end

    context "For the example skydns policy", :fixtures => true, :docker => true do
      let :docker_state do
        docker_state_fixture('test-1', 'test-2')
      end

      subject do
        described_class.load(fixture_path(:policy, 'skydns.rb'))
      end

      let :policy_config do
        subject.config_model.new(domain: 'kontena.local', network: 'bridge')
      end

      let :apply_context do
        subject.apply_context(policy_config)
      end

      it "returns etcd nodes for two containers" do
        expect(subject.apply(docker_state, apply_context)).to eq(
          '/skydns/local/kontena/test-1' => '{"host":"172.18.0.2"}',
          '/skydns/local/kontena/test-2' => '{"host":"172.18.0.3"}',
        )
      end
    end
  end

  describe '#loads' do
    context "For a test policy", :fixtures => true do
      it "Loads each policy .rb file" do
        subjects = described_class.loads(fixture_path(:policy))

        expect(subjects.map{|policy| policy.name}).to contain_exactly('test', 'skydns')
      end
    end
  end
end
