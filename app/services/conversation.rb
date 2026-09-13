module Conversation
  class Error < StandardError; end
  class StaleVersion < Error; end
  class NotAuthorized < Error; end
  class Inactive < Error; end
  class InvalidTransition < Error; end
end
