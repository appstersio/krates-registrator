# Kontena Registrator

Register Docker containers to etcd for different applications.

The `Kontena::Registrator` module implements generic Docker -> `etcd` mechanisms, and allows the use of a declarative ***policy*** for configuring how Docker containers are translated into etcd nodes.

## Development

This needs the `kontena-etcd` gem vendored under `vendor/kontena`:

`git submodule update --init`

Use bundler to install gemfile deps:

`bundle install --path vendor/bundle`

## Usage

Run with a Ruby policy:

`bundle exec bin/kontena-registrator etc/services/skydns.rb`

## Config

### `ETCD_ENDPOINT=http://127.0.0.1:2379`

Connect to etcd
