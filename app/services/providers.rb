module Providers
  class Error < StandardError
    attr_reader :recoverable

    def initialize(message, recoverable: true)
      super(message)
      @recoverable = recoverable
    end
  end

  class MissingCredentials < Error
    def initialize(variable)
      super("#{variable} is not set", recoverable: false)
    end
  end
end
