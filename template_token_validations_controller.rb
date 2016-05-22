module Overrides
  class TokenValidationsController < DeviseTokenAuth::TokenValidationsController

    def validate_token
      begin
        @resource.skip_image_storage = true if @resource
        super
      ensure
        @resource.skip_image_storage = false if @resource
      end
    end
  end
end