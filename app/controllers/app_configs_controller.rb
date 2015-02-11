class AppConfigsController < ApplicationController
  before_action :set_app_config, only: [:show, :edit, :update, :destroy]

  respond_to :html

  def index
    @app_configs = AppConfig.all
    respond_with(@app_configs)
  end

  def show
    respond_with(@app_config)
  end

  def new
    @app_config = AppConfig.new
    respond_with(@app_config)
  end

  def edit
  end

  def create
    @app_config = AppConfig.new(app_config_params)
    @app_config.save
    respond_with(@app_config)
  end

  def update
    @app_config.update(app_config_params)
    redirect_to action: 'index'
  end

  def destroy
    @app_config.destroy
    respond_with(@app_config)
  end

  private
    def set_app_config
      @app_config = AppConfig.find(params[:id])
    end

    def app_config_params
      params.require(:app_config).permit(:events)
    end
end
