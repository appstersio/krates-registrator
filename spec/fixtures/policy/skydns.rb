DOMAIN = ENV.fetch('SKYDNS_DOMAIN', 'skydns.local')
NETWORK = ENV['SKYDNS_NETWORK']

config do
  etcd_path '/kontena/registrator/services/skydns/:service'

  json_attr :domain, default: DOMAIN
  json_attr :network, default: NETWORK

  def skydns_path(name)
    File.join(['/skydns', domain.split('.').reverse, name].flatten)
  end
end

docker_container -> (container) {
  STDERR.puts "container=#{container} config=#{config.inspect}"
  STDERR.puts "config.class=#{config.class}"

  # stopped container has an empty IPAddress
  if ip = container['NetworkSettings', 'Networks', config.network, 'IPAddress']
    {
      config.skydns_path(container.hostname) => { host: ip },
    }
  end
}
