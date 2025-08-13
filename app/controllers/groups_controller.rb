class GroupsController < ApplicationController
  def index
    @groups = Group.all
    render json: {
      groups: @groups.map { |group| {
        id: group.group_id,
        name: group.name
      } }
    }
  end

  def show 
    @group = Group.find(params[:id])
    render json: {
      group: {
        id: @group.group_id,
        name: @group.name
      }
    }
  end

  def create
    @group = Group.find_or_create_by(group_id: params[:group_id]) do |group|
      group.name = params[:name]
    end
    
    if @group.persisted?
      render json: @group, status: :created
    else
      render json: { errors: @group.errors.full_messages }, status: :unprocessable_entity
    end
  end
end