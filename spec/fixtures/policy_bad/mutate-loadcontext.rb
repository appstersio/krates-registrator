load_context = self

docker_container -> (container) {
  load_context.docker_container -> (container2) {
    fail
  }
}
