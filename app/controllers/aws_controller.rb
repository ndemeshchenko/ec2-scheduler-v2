class AwsController < ApplicationController

  before_action :authenticate_user!

  def index
  	@ct_events = CloudTrailLog.all.desc('event_time')
  end

  def events
  	@ct_events = CloudTrailLog.all.desc('event_time')
  	render :json => @ct_events
  end

end