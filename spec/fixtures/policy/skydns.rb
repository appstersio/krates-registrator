DOMAIN = ENV.fetch('SKYDNS_DOMAIN', 'skydns.local')
NETWORK = ENV['SKYDNS_NETWORK']

config etcd_path: '/kontena/registrator/services/skydns/:service' do
  json_attr :domain, default: DOMAIN
  json_attr :network, default: NETWORK

  def skydns_path(name)
    File.join(['/skydns', domain.split('.').reverse, name].flatten)
  end
end

docker_container -> (container) {
  # stopped container has an empty IPAddress
  if ip = container['NetworkSettings', 'Networks', config.network, 'IPAddress']
    {
      config.skydns_path(container.hostname) => { host: ip },
    }
  end
}
