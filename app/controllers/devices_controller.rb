class DevicesController < ApplicationController
  
  # GET /devices/:id
  def show
    @device = UserDevice.find(params[:id])
    render json: @device
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Device not found' }, status: :not_found
  end

  # POST /devices
  def create
    # デバイスがすでに存在するか確認
    existing_device = UserDevice.find_by(device_id: device_params[:device_id])
    if existing_device
      render json: existing_device, status: :ok
      return
    end

    @device = UserDevice.new(device_params)
    
    if @device.save
      render json: @device, status: :created
    else
      render json: @device.errors, status: :unprocessable_entity
    end
  end

  private

  def device_params
    params.require(:device).permit(:firebase_uid, :device_id)
  end
end