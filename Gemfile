# frozen_string_literal: true

ruby '>= 2.3.1'

source 'https://rubygems.org' do
  gem 'celluloid', '~> 0.17.3'
  gem 'docker-api', '~> 1.33.0'
  gem 'safe_yaml'

  group :test do
    gem 'rspec', '~> 3.5'

    # XXX: transitive development dependencies from kontena-etcd
    gem 'rack-test'
    gem 'sinatra'
    gem 'webmock'
  end

  gem 'kontena-etcd', :path => 'vendor/kontena/kontena-etcd'
end

gemspec
