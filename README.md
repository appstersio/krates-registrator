# Kontena Registrator

Register Docker containers to etcd for different applications.

The `Kontena::Registrator` module implements generic Docker -> `etcd` mechanisms, and allows the use of a declarative ***policy*** for configuring how Docker containers are translated into etcd nodes.

## Install

This needs the `kontena-etcd` gem vendored under `vendor/kontena`:

`git clone git@github.com:SpComb/kontena-etcd.git vendor/kontena/kontena-etcd`

## Usage

Run with a Ruby policy:

`bundle exec bin/kontena-registrator etc/services/skydns.rb`
