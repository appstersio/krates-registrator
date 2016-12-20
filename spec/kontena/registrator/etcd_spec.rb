require 'kontena/registrator'
require 'kontena/registrator/etcd'

describe Kontena::Registrator::Etcd::Writer do
  subject { described_class.new }

  context "for an empty etcd", etcd: true do
    it "writes out a node" do |ex|
      subject.update(
        '/kontena/test1' => { 'test' => 1 }.to_json,
      )

      expect(etcd_server.logs).to eq [
        [:set, '/kontena/test1'],
      ]
      expect(etcd_server.nodes).to eq(
        '/kontena/test1' => { 'test' => 1 },
      )
    end

    it "keeps an existing node" do |ex|
      subject.update(
        '/kontena/test1' => { 'test' => 1 }.to_json,
      )
      subject.update(
        '/kontena/test1' => { 'test' => 1 }.to_json,
      )

      expect(etcd_server.logs).to eq [
        [:set, '/kontena/test1'],
      ]
      expect(etcd_server.nodes).to eq(
        '/kontena/test1' => { 'test' => 1 },
      )
    end

    it "updates a node" do |ex|
      subject.update(
        '/kontena/test1' => { 'test' => 1 }.to_json,
      )
      subject.update(
        '/kontena/test1' => { 'test' => 2 }.to_json,
      )

      expect(etcd_server.logs).to eq [
        [:set, '/kontena/test1'],
        [:set, '/kontena/test1'],
      ]
      expect(etcd_server.nodes).to eq(
        '/kontena/test1' => { 'test' => 2 },
      )
    end

    it "deletes a node" do |ex|
      subject.update(
      '/kontena/test1' => { 'test' => 1 }.to_json,
      )
      subject.update({})

      expect(etcd_server.logs).to eq [
        [:set, '/kontena/test1'],
        [:delete, '/kontena/test1'],
      ]
      expect(etcd_server.nodes).to eq({})
    end

    it "replaces a node" do |ex|
      subject.update(
        '/kontena/test1' => { 'test' => 1 }.to_json,
      )
      subject.update(
        '/kontena/test2' => { 'test' => 2 }.to_json,
      )

      expect(etcd_server.logs).to eq [
        [:set, '/kontena/test1'],
        [:set, '/kontena/test2'],
        [:delete, '/kontena/test1'],
      ]
      expect(etcd_server.nodes).to eq(
        '/kontena/test2' => { 'test' => 2 },
      )
    end
  end
end
