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

    it "returns etcd nodes for two containers" do
      expect(subject.apply(docker_state)).to eq(
        '/skydns/local/skydns/test-1' => '{"host":"172.18.0.2"}',
        '/skydns/local/skydns/test-2' => '{"host":"172.18.0.3"}',
      )
    end
  end
end
