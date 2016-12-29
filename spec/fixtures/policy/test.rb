docker_container -> (container) {
  {
    "/kontena/test/#{container.hostname}" => container['NetworkSettings', 'IPAddress'],
  }
}
