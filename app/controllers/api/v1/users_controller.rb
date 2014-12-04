include ActionController::HttpAuthentication::Token

module Api
  module V1
    class UsersController < ApplicationController
      def create_new_session
        api_key = token_and_options(request)[0]
        user = User.find_or_create_api_user(
          params[:user_id], 
          params[:username], 
          api_key)

        sign_in(user)
        redirect_to campaigns_path
      end
    end
  end
end