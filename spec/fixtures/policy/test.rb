docker_container -> (container) {
  {
    "/skydns/local/skydns/#{container.hostname}" => { host: container['NetworkSettings', 'IPAddress'] },
  }
}
