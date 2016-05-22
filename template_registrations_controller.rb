module Overrides
  class RegistrationsController < DeviseTokenAuth::RegistrationsController

    before_filter :configure_sign_up_params, only: [:create]
    before_filter :configure_account_update_params, only: [:update]

    private

      def configure_sign_up_params
        devise_parameter_sanitizer.for(:sign_up).push(:name)
      end

      def configure_account_update_params
        devise_parameter_sanitizer.for(:account_update).push(:name)
      end

  end
end