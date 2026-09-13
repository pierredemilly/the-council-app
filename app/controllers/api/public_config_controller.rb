module Api
  class PublicConfigController < BaseController
    def show
      render json: Conversation::ConfigSnapshot.new(Conversation::ConfigSnapshot.capture).public_payload
    end
  end
end
