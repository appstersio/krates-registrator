require 'kontena/observable'

describe Kontena::Observable, :celluloid => true do
  subject do
    described_class.new
  end

  let :updater_class do
    Class.new do
      include Celluloid
      include Kontena::Logging


      def initialize(observable)
        @observable = observable
      end

      def run(last)
        logger.debug "updater run start"

        for value in 1..last do
          @observable.update(value)
        end

        logger.debug "updater run complete with value=#{value}"
      end
    end
  end

  let :observer_class do
    Class.new do
      include Celluloid
      include Kontena::Logging

      def initialize(observable)
        @observable = observable
        @value = nil
      end

      # Observe updates, and return the final value
      def run
        logger.debug "observer run start"

        @observable.observe do |value|
          @value = value
        end

        logger.debug "observer run complete with value=#{@value}"

        @value
      end
    end
  end

  it "each actor observes the last value updated by one actor" do
    $CELLULOID_DEBUG = true

    update_actor = updater_class.new(subject)
    observer_actors = (1..10).map {
      observer_class.new(subject)
    }
    observer_futures = observer_actors.map {|actor|
      actor.future.run
    }

    # run a large number of Updates
    update_actor.run(1000)

    # allow the observing actors to return
    subject.close

    # collect results
    observer_results = observer_futures.map {|future|
      future.value
    }

    expect(observer_results).to eq [1000] * 10

  end
end
