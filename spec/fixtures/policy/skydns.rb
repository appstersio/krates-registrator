DOMAIN = ENV.fetch('SKYDNS_DOMAIN', 'skydns.local')
NETWORK = ENV['SKYDNS_NETWORK']

config etcd_path: '/kontena/registrator/services/skydns/:service' do
  json_attr :domain, default: DOMAIN
  json_attr :network, default: NETWORK
end

helpers do
  def skydns_path(domain, name)
    File.join(['/skydns', domain.split('.').reverse, name].flatten)
  end
end

docker_container -> (container) {
  # stopped container has an empty IPAddress
  if ip = container['NetworkSettings', 'Networks', config.network, 'IPAddress']
    {
      skydns_path(config.domain, container.hostname) => { host: ip },
    }
  end
}
