require 'logger'

module Kontena
  # per-class logger, using the class name as the progname
  #
  # Use LOG_LEVEL=debug to configure
  module Logging
    @log_level = ENV.fetch('LOG_LEVEL', Logger::INFO)

    def self.log_level
      @log_level
    end
    def log_level=(level)
      @log_level = level
    end

    module ClassMethods
      def log_level=(level)
        @log_level = level
      end

      def logger(progname: self.class.name, level: @log_level || Kontena::Logging.log_level)
        logger = Logger.new(STDERR)
        logger.level = level
        logger.progname = progname

        return logger
      end
    end

    def self.included(base)
      base.extend ClassMethods
    end

    # @return [Logger]
    def logger(**opts)
      if opts
        self.class.logger **opts
      else
        @logger ||= self.class.logger
      end
    end
  end
end
