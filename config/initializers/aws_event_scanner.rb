require 'rufus-scheduler'
require 'pry'
require 'aws-sdk-core'
require 'json'


scheduler = Rufus::Scheduler.singleton

scheduler.every '2m' do
	main
end

@event_types = [
	'StopInstances', 
	'RunInstances', 
	'RebootInstances', 
	'CreateSecurityGroup', 
	'AuthorizeSecurityGroupIngress',
	'AuthorizeSecurityGroupEgress',
	'DeleteSecurityGroup',
	'ModifyNetworkInterfaceAttribute',
	'StartInstances',
	'ModifyDBInstance',
	'DeregisterInstancesFromLoadBalancer',
	'CreateSnapshot'
]


def main
	puts 'Trigger AwsEventScanner::Main'
	logs = logs = Aws::CloudWatchLogs::Client.new(region: 'us-east-1')
	events_resp = logs.get_log_events(
		log_group_name: "CloudTrail/DefaultLogGroup",
		log_stream_name: "600690756780_CloudTrail_us-east-1",
		start_time: ((Time.now - 1*60*60).to_i.to_s + "000").to_i,
		end_time: (Time.now.to_i.to_s + "000").to_i,
		# limit: 10000
		# start_from_head: true
	)
	list = []
	events_resp.events.each do |event|
		j_event = JSON.parse(event.message)
		# if j_event['userIdentity']['userName'] != 'elementum'
			if @event_types.include? j_event['eventName']
				unless CloudTrailLog.where(event_id: j_event['eventID']).size > 0
					new_ct_event = CloudTrailLog.new(
						event_id: j_event['eventID'],
						log_event: j_event,
						event_name: j_event['eventName']
					)
					new_ct_event.save!
				end
				puts "#{j_event['eventTime']} #{j_event['userIdentity']['userName']} #{j_event['eventName']}"
			end
		# end
		# puts Time.at(event.ingestion_time.to_s.split('')[0..9].join.to_i).to_datetime.to_time
		list << JSON.parse(event.message)['eventName']
	end

	puts list.uniq

end

main
# Time.at(events_resp.events.first.ingestion_time.to_s.split('')[0..9].join.to_i).to_datetime


# StopInstances
