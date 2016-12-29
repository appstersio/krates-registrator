require 'uri'

module DockerHelpers
  include FixtureHelpers

  def docker_fixture(type, name)
    path = File.join(FIXTURES_PATH, 'docker', type.to_s, name + '.json')

    File.open(path) do |file|
      JSON.load(file)
    end

  rescue JSON::ParserError => error
    raise "Invalid #{path}: #{error}"
  end

  def docker_fixtures(type, *names)
    names.map{|name| docker_fixture(type, name)}.flatten
  end

  def docker_container_fixture(name)
    json = docker_fixture(:inspect, name)

    Kontena::Registrator::Docker::Container.new(json['Id'], json)
  end

  def docker_state_fixture(*names)
    containers = Hash[names.map{|name|
      container = docker_container_fixture(name)
      [container.id, container]
    }]
    Kontena::Registrator::Docker::State.new(containers)
  end

  def stub_docker(path, **query)
    uri = URI::HTTP.build(host: 'unix', path: "/v#{Docker::API_VERSION}/#{path}",
      query: URI.encode_www_form(**query)
    )

    stub_request(:get, uri.to_s)
      .to_return(
        :headers => {
          'Content-Type' => 'application/json',
        },
        :body => (yield).to_json,
      )
  end
end
