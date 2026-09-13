module Users
  class RegistrationsController < Devise::RegistrationsController
    respond_to :json

    before_action :require_signup_enabled, only: %i[new create]

    def self.signup_enabled?
      !Rails.env.production? || ActiveModel::Type::Boolean.new.cast(ENV["ALLOW_SIGNUP"]) == true
    end

    private

    def require_signup_enabled
      return if self.class.signup_enabled?

      render json: { error: I18n.t("devise.registrations.disabled") }, status: :forbidden
    end

    def respond_with(resource, _opts = {})
      if resource.persisted?
        render json: { user: UserSerializer.new(resource).serializable_hash }, status: :created
      else
        render json: { errors: resource.errors.full_messages }, status: :unprocessable_entity
      end
    end
  end
end
