domain = ENV.fetch('SKYDNS_DOMAIN', 'skydns.local')
network = ENV['SKYDNS_NETWORK'] or raise "No SKYDNS_NETWORK="

docker_container ->(container) {
  if kontena_ip = container.networks.dig(network, 'IPAddress')
    {
      "/skydns/#{domain.split('.').reverse.join('/')}/#{container.hostname}" => { host: kontena_ip }.to_json,
    }
  end
}
