# Kontena Registrator

Register Docker containers to etcd for different applications.

The `Kontena::Registrator` module implements generic Docker -> `etcd` mechanisms, and allows the use of a declarative ***policy*** for configuring how Docker containers are translated into etcd nodes.

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

## Rules

### Node merging

Multiple Docker containers can register the same etcd node for a given Policy.
This will behave deterministically when each container registers exactly the same value for that etcd node.

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
