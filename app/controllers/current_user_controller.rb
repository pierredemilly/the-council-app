class CurrentUserController < ApplicationController
  def show
    user = user_signed_in? ? UserSerializer.new(current_user).serializable_hash : nil
    render json: { user: user, signup_enabled: Users::RegistrationsController.signup_enabled? }
  end
end
