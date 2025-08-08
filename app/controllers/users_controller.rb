class UsersController < ApplicationController
  # GET /users
  def index
    @users = User.all
    render json: @users
  end

  # GET /users/:id (where id is firebase_uid)
  def show
    @user = User.find(params[:id])
    render json: @user
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'User not found' }, status: :not_found
  end

  # POST /users
  def create
    # ユーザーがすでに存在するか確認
    existing_user = User.find_by(firebase_uid: user_params[:firebase_uid])
    if existing_user
      render json: existing_user, status: :ok
      return
    end
    @user = User.new(user_params)

    if @user.save
      render json: @user, status: :created
    else
      render json: @user.errors, status: :unprocessable_entity
    end
  end

  private

  def user_params
    params.require(:user).permit(:name, :firebase_uid, :email)
  end
end