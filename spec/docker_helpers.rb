module DockerHelpers
  FIXTURES_PATH = File.join(File.dirname(__FILE__), 'fixtures')

  def docker_fixture(type, name)
    path = File.join(FIXTURES_PATH, 'docker', type.to_s, name + '.json')

    File.open(path) do |file|
      JSON.load(file)
    end
  end

  def docker_fixtures(type, *names)
    names.map{|name| docker_fixture(type, name)}.flatten
  end

  def docker_container_fixture(name)
    json = docker_fixture(:inspect, name).first

    Kontena::Registrator::Docker::Container.new(json['Id'], json)
  end

  def docker_state_fixture(*names)
    containers = Hash[names.map{|name|
      container = docker_container_fixture(name)
      [container.id, container]
    }]
    Kontena::Registrator::Docker::State.new(containers)
  end
end
