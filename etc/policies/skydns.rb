DOMAIN = ENV.fetch('SKYDNS_DOMAIN', 'skydns.local')
NETWORK = ENV['SKYDNS_NETWORK']

config do
  etcd_path '/kontena/registrator/services/skydns/:service'

  json_attr :domain, default: DOMAIN
  json_attr :network, default: NETWORK

  # TODO: def skydns_path
end

docker_container -> (container) {
  # stopped container has an empty IPAddress
  if ip = container['NetworkSettings', 'Networks', config.network, 'IPAddress']
    {
      "/skydns/#{config.domain.split('.').reverse.join('/')}/#{container.hostname}" => { host: ip },
    }
  end
}
