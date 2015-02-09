class AwsController < ApplicationController

  before_action :authenticate_user!

  def index
  	@ct_events = CloudTrailLog.all
  end

end