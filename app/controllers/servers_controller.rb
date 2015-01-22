class ServersController < ApplicationController
  before_action :set_server, only: [:show, :edit, :update, :destroy]

  respond_to :html

  def index
    @servers = Server.all
    respond_with(@servers)
  end

  def show
    respond_with(@server)
  end

  def new
    @server = Server.new
    respond_with(@server)
  end

  def edit
  end

  def create
    @server = Server.new(server_params)
    @server.save
    respond_with(@server)
  end

  def update
    @server.update(server_params)
    respond_with(@server)
  end

  def destroy
    @server.destroy
    respond_with(@server)
  end

  private
    def set_server
      @server = Server.find(params[:id])
    end

    def server_params
      params.require(:server).permit(:instance_id, :hostname, :url, :state, :schedule_days, :schedule_hours, :locked)
    end
end
