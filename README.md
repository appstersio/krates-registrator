# Kontena Registrator

Register Docker containers to etcd for different applications.

The `Kontena::Registrator` module implements generic Docker -> `etcd` mechanisms, and allows the use of a declarative ***policy*** for configuring how Docker containers are translated into etcd nodes.

## Development

This needs the `kontena-etcd` gem vendored under `vendor/kontena`:

`git submodule update --init`

Use bundler to install gemfile deps:

`bundle install --path vendor/bundle`

## Usage

Run with a bundler:

`KONTENA_REGISTRATOR_POLICIES=etc/policies/*.rb bundle exec bin/kontena-registrator`

Run with Docker:

`docker run --rm --name kontena-registrator --net host -v /var/run/docker.sock:/var/run/docker.sock -e LOG_LEVEL=info -e KONTENA_REGISTRATOR_POLICIES=etc/policies/*.rb kontena/registrator`

## Config

### `KONTENA_REGISTRATOR_POLICIES=etc/policies/*.rb`

Load policies for configuration.

### `LOG_LEVEL=...`

* `debug`
* `info`
* `warn`
* `error`
* `fatal`

### `ETCD_ENDPOINT=http://127.0.0.1:2379`

Connect to etcd

## Build

`docker build -t kontena/registrator .`
