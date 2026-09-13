module Api
  module Admin
    class BaseController < ApplicationController
      before_action :authenticate_user!

      rescue_from Providers::Error do |error|
        render json: { error: error.message }, status: :bad_gateway
      end

      private

      def render_invalid(record)
        render json: { errors: record.errors.full_messages }, status: :unprocessable_content
      end
    end
  end
end
