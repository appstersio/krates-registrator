# Kontena Registrator

Use very simple declarative Ruby DSL [Policies](#Policy) to register etcd configuration nodes for Docker containers, with an automatic mechanism to handle configuration node updates and removals.

Supports JSON configuration for policies, including multiple dynamically managed policy instances loaded from etcd.

## Example
### `etc/policies/skydns.rb`

```ruby
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
```


## Development

This needs the `kontena-etcd` gem vendored under `vendor/kontena`:

`git submodule update --init`

Use bundler to install gemfile deps:

`bundle install --path vendor/bundle`

## Usage

### Bundler
Run with Bundler:

`KONTENA_REGISTRATOR_POLICIES=etc/policies/*.rb bundle exec bin/kontena-registrator`

### Docker
Build with Docker:

`docker build -t kontena/registrator .

Run with Docker:

`docker run --rm --name kontena-registrator --net host -v /var/run/docker.sock:/var/run/docker.sock -e LOG_LEVEL=info -e KONTENA_REGISTRATOR_POLICIES=etc/policies/*.rb kontena/registrator`

## Config

### `KONTENA_REGISTRATOR_POLICIES=etc/policies/`

Load `*.rb` policy files.

### `KONTENA_REGISTRATOR_SERVICES=etc/services/`

Load local `:policy/*.json` service configuration for policies.

### `LOG_LEVEL=...`

* `debug`
* `info`
* `warn`
* `error`
* `fatal`

### `ETCD_ENDPOINT=http://127.0.0.1:2379`

Connect to etcd at given address

## Policy

A declarative function mapping Docker container states to etcd nodes having a key and value.

Policies are written as Ruby DSLs, registering a `docker_container -> (container) { ... }` lambda function that takes an (immutable) `Kontena::Registrator::Docker::Container` as an argument, and returns a Hash of `{ etcd-key => etcd-value }`.

The `etcd-key` must be a String giving an etcd `/path` to the node to register.

The `etcd-value` can either be any of:

* `nil`: omit this etcd node
* `String`: raw string value
* any JSON-encodable value (`true`, `false`, `Integer`, `Float`, `Array`, `Hash`)

### Configuration

Each Policy can also support JSON configuration. Use the `config do ... end` to define the configuration schema, using `Kontena::JSON::Model#json_attr` statements:

```ruby
config do
  json_attr :domain, default: 'skydns.local'
  json_attr :network, default: 'bridge'
end
```

### Dynamic Configuration from `etcd`

The policies can also be configured dynamically, using JSON objects in etcd, using the `Kontena::Etcd::Model#etcd_path` statement:

```ruby
config do
  etcd_path '/kontena/registrator/services/skydns/:service'

  ...
end
```

A new instance of the policy will be created for each matching node in etcd.
The service instances will automatically be dynamically started, reloaded and stopped as the etcd configuration changes.

## Mechanism

The `Kontena::Registrator::Docker` mechanism is used to observe the state of local Docker containers.

Every time the Docker state changes, the policy is re-evaluated for each Docker container.
Each such policy evaluation results in a single set of etcd nodes to register.

The `Kontena::Registrator::Service` and `Kontena::Etcd::Writer` mechanisms are used to register these policy-generated nodes into etcd.
Each time the policy is re-evaluated, the node set of etcd nodes is compared with the current set of nodes written to etcd.
Any new or changed nodes are stored into etcd, and any nodes that are no longer known will be removed from etcd.
This means that if a Docker container is destroyed, any etcd nodes registered by the Policy for that container will automatically be removed.

The mechanisms are implemented using Celluloid Actors for fault-tolernace, where the system is able to survive and resume operation across any Docker and `etcd` API failures.

Multiple Docker containers may also register the same etcd node for a given Policy.
This will behave correctly when each container registers exactly the same value for that etcd node (XXX: except when un-registering nodes across different machines).

#### §0 a single Docker container for a single Policy registers an etcd node with some value

The policy will register the etcd node with that value.

The etcd node will remain registered with that value so long as the policy keeps evaluating to that node.

The etcd node will be re-registered with a new value if the policy evaluates to a different value for that node.

The etcd node will be un-registered once the policy no longer evaluates to that node.

The etcd node will be expired from etcd if the Policy crashes and is unable to restart.

#### §1 multiple Docker containers for the same Policy register the same etcd node with the same value

The policy will register the etcd node with that value.

The etcd node will remain registered with that value so long as any Docker container registers that node.

The etcd node will be un-registered once no more Docker containers register that node.

#### §2 multiple Docker containers for the same Policy register the same etcd node with a different value

The policy will register the etcd node with the smaller of the two values, and log a warning.

This reverts to rule 1 if the container registering a conflicting value goes away, and the remaining Policies agree on the same value.

#### §3 multiple Policies (across different machines) register the same etcd node with the same value

Both policies will set and refresh the node in tandem.

TODO: this currently breaks if one of the policies un-registers the node; it will be removed from etcd.
The remaining policies will detect the removal during their refresh cycle, crash, restart and re-register the node in etcd.

#### §4 multiple Policies (across different machines) register the same etcd node with a different value

Each policy will take turns crashing, restarting, and re-setting the node to one of the two values.
The node value in etcd will keep bouncing between the different values until the Policies agree on one value.

## Tests
Run tests, using an internal etcd server:

`bundle exec rspec`

Run tests, using an external etcd server (this will destroy the `/kontena` sub-tree):

`ETCD_ENDPOINT=http://127.0.0.1:2379 bundle exec rspec`
