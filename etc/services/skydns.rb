domain = ENV.fetch('SKYDNS_DOMAIN', 'skydns.local')
network = ENV['SKYDNS_NETWORK'] or raise "No SKYDNS_NETWORK="

docker_container -> (container) {
  # stopped container has an empty IPAddress
  if ip = container['NetworkSettings', 'Networks', network, 'IPAddress']
    {
      "/skydns/#{domain.split('.').reverse.join('/')}/#{container.hostname}" => { host: ip },
    }
  end
}
