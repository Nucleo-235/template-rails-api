class UsersController < ApplicationController
  before_action :authenticate_user!
  
  def me
    render json: current_user
  end

  def update_image
    current_user.update(update_image_params)
    render json: current_user
  end

  def update_image_params
    params.permit(:image, :image_cache)
  end
end
