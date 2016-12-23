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

  context "for a configurable SkyDNS policy", :docker => true do
    subject do
      policy = described_class.new(:skydns)
      policy.context.config do
        etcd_path '/kontena/registrator/services/skydns/:service'

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

    let :config_class do
      subject.context[:config]
    end

    let :policy_config do
      config_class.new('test', domain: 'kontena.local')
    end

    let :apply_context do
      subject.apply_context(policy_config)
    end

    it "returns etcd nodes for two containers" do
      expect(config_class.included_modules).to include(Kontena::Etcd::Model, Kontena::JSON::Model)
      expect(policy_config.domain).to eq 'kontena.local'
      expect(policy_config.network).to eq 'bridge'

      expect(subject.apply(docker_state, apply_context)).to eq(
        '/skydns/local/kontena/test-1' => '{"host":"172.18.0.2"}',
        '/skydns/local/kontena/test-2' => '{"host":"172.18.0.3"}',
      )
    end
  end
end
