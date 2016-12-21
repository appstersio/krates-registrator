require 'logger'

module Kontena
  module Logging
    def logger!(progname: self.class.name)
      logger = Logger.new(STDERR)
      logger.level = Logger::DEBUG
      logger.progname = progname

      return logger
    end

    # @return [Logger]
    def logger
      @logger ||= self.logger!
    end
  end
end
