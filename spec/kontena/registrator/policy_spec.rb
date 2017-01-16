describe Kontena::Registrator::Policy do
  describe '#apply_nodes' do
    it "Skips an nil hash" do
      expect(Kontena::Registrator::Policy.apply_nodes(nil)).to eq({})
    end

    it "Skips an nil value" do
      expect(Kontena::Registrator::Policy.apply_nodes({'/kontena/test' => nil})).to eq({})
    end

    it "Raises on a non-hash" do
      expect{Kontena::Registrator::Policy.apply_nodes('test')}.to raise_error(ArgumentError, /Expected Hash, got String: "test"/)
    end
  end

  context "for a policy that registers a lambda", :docker => true do
    subject do
      described_class.new(:skydns) do
        docker_container -> (container) {
          {
            "/kontena/test/#{container.hostname}" => { host: container['NetworkSettings', 'IPAddress'] },
          }
        }
      end
    end

    let :docker_state do
      docker_state_fixture('test-1', 'test-2')
    end

    it "returns etcd nodes for two containers" do
      expect(subject.context.apply(docker_state)).to eq(
      '/kontena/test/test-1' => '{"host":"172.18.0.2"}',
      '/kontena/test/test-2' => '{"host":"172.18.0.3"}',
      )
    end
  end

  context "for a policy that returns a hash", :docker => true do
    subject do
      described_class.new(:skydns) do
        def docker_container (container)
          return {
            "/kontena/test/#{container.hostname}" => { host: container['NetworkSettings', 'IPAddress'] },
          }
        end
      end
    end

    let :docker_state do
      docker_state_fixture('test-1', 'test-2')
    end

    it "returns etcd nodes for two containers" do
      expect(subject.context.apply(docker_state)).to eq(
      '/kontena/test/test-1' => '{"host":"172.18.0.2"}',
      '/kontena/test/test-2' => '{"host":"172.18.0.3"}',
      )
    end
  end

  context "for a policy that yields", :docker => true do
    subject do
      described_class.new(:skydns) do
        def docker_container(container)
          yield "/kontena/test/#{container.hostname}" => { host: container['NetworkSettings', 'IPAddress'] }
        end
      end
    end

    let :docker_state do
      docker_state_fixture('test-1', 'test-2')
    end

    it "returns etcd nodes for two containers" do
      expect(subject.context.apply(docker_state)).to eq(
        '/kontena/test/test-1' => '{"host":"172.18.0.2"}',
        '/kontena/test/test-2' => '{"host":"172.18.0.3"}',
      )
    end
  end

  context "for a policy that produces overlapping nodes", :docker => true do
    subject do
      described_class.new(:skydns) do
        docker_container -> (container) {
          {
            "/kontena/test" => { hostname: container.hostname },
          }
        }
      end
    end

    context "for two different node values" do
      let :docker_state do
        docker_state_fixture('test-1', 'test-2')
      end

      let :context do
        subject.context
      end

      it "logs a warning and returns the smaller of the two nodes" do
        expect(context.logger).to receive(:warn)
        expect(context.apply(docker_state)).to eq(
          '/kontena/test' => '{"hostname":"test-1"}',
        )
      end
    end

    context "for two identical node values" do
      let :docker_state do
        docker_state_fixture('test-1', 'test-1')
      end

      let :context do
        subject.context
      end

      it "returns that node" do
        expect(context.logger).to_not receive(:warn)
        expect(context.apply(docker_state)).to eq(
          '/kontena/test' => '{"hostname":"test-1"}',
        )
      end
    end
  end

  context "for a policy that mutates the context class", :docker => true do
    subject do
      described_class.new(:test) do
        def docker_container(container)
          self.class.include Comparable
        end
      end
    end

    let :docker_state do
      docker_state_fixture('test-1')
    end

    it "raises an error" do
      expect{subject.context.apply(docker_state)}.to raise_error(RuntimeError, /can't modify frozen/)
    end
  end

  context "for a policy that mutates the context instance", :docker => true do
    subject do
      described_class.new(:test) do
        def docker_container(container)
          @config = nil
        end
      end
    end

    let :docker_state do
      docker_state_fixture('test-1')
    end

    it "raises an error" do
      expect{subject.context.apply(docker_state)}.to raise_error(RuntimeError, /can't modify frozen/)
    end
  end

  context "for a policy that mutates the config instance", :docker => true do
    subject do
      described_class.new(:test) do
        config do
          def test
            @test = true
          end
        end
        def docker_container(container)
          { '/kontena/test' => config.test }
        end
      end
    end

    let :config do
      subject.config_model.new()
    end

    let :context do
      subject.context(config)
    end

    let :docker_state do
      docker_state_fixture('test-1')
    end


    it "raises an error" do
      expect{context.apply(docker_state)}.to raise_error(RuntimeError, /can't modify frozen/)
    end
  end

  context "for a policy that mutates the config instance", :docker => true do
    subject do
      described_class.new(:test) do
        config do
          json_attr :test, default: 0
        end
        def docker_container(container)
          config.test += 1

          { '/kontena/test' => config.test }
        end
      end
    end

    let :config do
      subject.config_model.new()
    end

    let :context do
      subject.context(config)
    end

    let :docker_state do
      docker_state_fixture('test-1')
    end

    it "raises an error" do
      expect{context.apply(docker_state)}.to raise_error(RuntimeError, /can't modify frozen/)
    end
  end

  context "for a configurable SkyDNS policy", :docker => true do
    subject do
      described_class.new(:skydns) do
        config etcd_path: '/kontena/registrator/services/skydns/:service' do
          json_attr :domain, default: 'skydns.local'
          json_attr :network, default: 'bridge'
        end
        docker_container -> (container) {
          if ip = container['NetworkSettings', 'Networks', config.network, 'IPAddress']
            {
              "/skydns/#{config.domain.split('.').reverse.join('/')}/#{container.hostname}" => { host: ip },
            }
          end
        }
      end
    end

    let :docker_state do
      docker_state_fixture('test-1', 'test-2')
    end

    context "for a local config" do
      let :config do
        subject.config_model.new(domain: 'kontena.local')
      end

      it "returns etcd nodes for two containers" do
        expect(config.class.included_modules).to include(Kontena::JSON::Model)
        expect(config.domain).to eq 'kontena.local'
        expect(config.network).to eq 'bridge'

        expect(subject.context(config).apply(docker_state)).to eq(
          '/skydns/local/kontena/test-1' => '{"host":"172.18.0.2"}',
          '/skydns/local/kontena/test-2' => '{"host":"172.18.0.3"}',
        )
      end
    end

    context "for an etcd config", :etcd => true do
      before do
        etcd_server.load!(
          '/kontena/registrator/services/skydns/test' => { 'domain' => 'kontena.local' },
        )
      end

      let :config do
          subject.config_model_etcd.get('test')
      end

      let :context do
        subject.context(config)
      end

      it "loads a config from etcd" do
        expect{config}.to_not raise_error
        expect(config).to have_attributes(service: 'test', domain: 'kontena.local', network: 'bridge')
      end

      it "returns etcd nodes for two containers" do
        expect(config.class.included_modules).to include(Kontena::Etcd::Model, Kontena::JSON::Model)
        expect(config.domain).to eq 'kontena.local'
        expect(config.network).to eq 'bridge'

        expect(context.apply(docker_state)).to eq(
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

      let :context do
        subject.context()
      end

      subject do
        described_class.load(fixture_path(:policy, 'test.rb'))
      end

      it "Loads a policy .rb file" do
        expect(subject.name).to eq 'test'
        expect(subject).to_not be_config
      end

      it "returns etcd nodes for two containers" do
        expect(context.apply(docker_state)).to eq(
          '/kontena/test/test-1' => "172.18.0.2",
          '/kontena/test/test-2' => "172.18.0.3",
        )
      end
    end

    context "For a bad policy that tries to mutate the load context", :fixtures => true, :docker => true do
      let :docker_state do
        docker_state_fixture('test-1', 'test-2')
      end

      let :context do
        subject.context()
      end

      subject do
        described_class.load(fixture_path(:policy_bad, 'mutate-loadcontext.rb'))
      end

      it "fails to apply" do
        expect{context.apply(docker_state)}.to raise_error(RuntimeError, /can't modify frozen class/)
      end
    end

    context "For the example skydns policy", :fixtures => true, :docker => true do
      let :docker_state do
        docker_state_fixture('test-1', 'test-2')
      end

      subject do
        described_class.load(fixture_path(:policy, 'skydns.rb'))
      end

      let :config do
        subject.config_model.new(domain: 'kontena.local', network: 'bridge')
      end

      let :context do
        subject.context(config)
      end

      it "has the :skydns_path helper method" do
        expect(context.class).to be_method_defined(:skydns_path)
      end

      it "returns etcd nodes for two containers" do
        expect(context.apply(docker_state)).to eq(
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
