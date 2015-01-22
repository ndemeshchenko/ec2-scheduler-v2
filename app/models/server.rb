require 'aws-sdk-core'

class Server
  include Mongoid::Document
  field :instance_id, type: String
  field :hostname, type: String
  field :url, type: String
  field :state, type: String
  field :schedule_days, type: String
  field :schedule_hours, type: String
  field :locked, type: Mongoid::Boolean

  def start_instance
  	ec2 = Aws::EC2::Client.new(region:'us-east-1')
  	resp = ec2.start_instances(
		dry_run: false,
		instance_ids: [instance_id]
	)
	status =  resp.first.starting_instances[0].current_state.name
	save
  end

  def stop_instance
  	puts 'triger for model Server.stop_instance'
  end

end
