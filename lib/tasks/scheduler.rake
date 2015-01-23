require 'pry'
require 'aws-sdk-core'
require 'json'

@ec2 = Aws::EC2::Client.new(region:'us-east-1')
@ses = Aws::SES::Client.new(region:'us-east-1')

namespace :scheduler do
  desc "TODO"
  task check: :environment do

	def in_uptime_range?(server)
		now = Time.now
		day_of_week = now.wday
		schedule_days = server.schedule_days.split(',')
		schedule_hours = server.schedule_hours.split('-')
		if schedule_days.include? schedule_days[day_of_week-1]
			return (now.hour >= schedule_hours[0].to_i and now.hour <= schedule_hours[1].to_i) ? true : false
		end
		return false
	end

	def update_instances_state(servers)
		# 0 : pending
		# 16 : running
		# 32 : shutting-down
		# 48 : terminated
		# 64 : stopping
		# 80 : stopped
		instance_ids = []
		servers.each do |server|
			instance_ids << server.instance_id
		end
		p instance_ids

		resp = @ec2.describe_instances(
  			dry_run: false,
  			instance_ids: instance_ids,
		)
		resp.reservations.each do |reservation|
			reservation.instances.each do |instance|
				i = Server.where(instance_id: instance['instance_id']).first
				i.state = instance['state']['name']
				i.save
				puts("#{Time.now.in_time_zone('Pacific Time (US & Canada)')} #{i.hostname} :: #{i.state}")
			end
		end
	end

	def send_email(server, owner, time)
		hibernation_notification_template = 
				"The following servers are scheduled to go down for hibernation:<p>" + 
				server.hostname + "@ #{time.hour}:#{time.min} " + 
				"<p><p>To cancel any of these hibernation, go to <a href='http://snoopy.escm.co:3000/servers/'>http://snoopy.escm.co</a> " + 
				"<p><p>To wake up instances already hibernating, go to TBD<SOMETHING APPROPRIATE HERE> " + 
				"<p><p>Thanks,<p>EngOps Bot"
		ses_resp = @ses.send_email(
		  source: "ec2-scheduler@elementum.com",
		  destination: {
		    to_addresses: ["nikita@elementum.com"],
		    # cc_addresses: ["techops@elementum.com"],
		  },
		  message: {
		    subject: {
		      data: "EC2 Scheduled hibernation notice",
		      charset: "utf-8",
		    },
		    body: {
		      html: {
		        data: hibernation_notification_template,
		        charset: "utf-8",
		      },
		    },
		  },
		  reply_to_addresses: ["techops@elementum.com"]
		)
		puts "message send to #{owner} :: #{ses_resp['message_id']} "
	end

	def stop_instance(server)
		unless Server.where(instance_id: server.instance_id).first.locked
			puts "going to stop instance. NO KIDDING HERE"

			#clear uncompleted event
			event = EventLog.where(state: 'notification', hostname: server.hostname, completed: false).first
			event.completed = true
			event.save

			resp = @ec2.stop_instances(
				dry_run: false,
				instance_ids: [server.instance_id]
			)

			server = Server.where(instance_id: server.instance_id).first
			server.state = resp.first.stopping_instances[0].current_state.name
			server.save
		end
	end

	def prepare_to_stop(server)
		events = EventLog.where(hostname: server.hostname, state: "notification", completed: false)
		# binding.pry
		log_date = events[0].date.in_time_zone("Pacific Time (US & Canada)") if events[0]
		log_date_plus_hour = log_date + 60 if events[0] # add 1 minute
		if events.size > 0
			if (log_date_plus_hour < Time.now.in_time_zone("Pacific Time (US & Canada)"))
				stop_instance server;
			end
		else
			send_email(server, "server.owner", Time.now + 60)
			puts("instance "+ server.hostname + " scheduled to stop at: #{Time.now + 60}");
			new_event = EventLog.new(
				eventName: 'email sent to server owner', 
				state: 'notification',
  				hostname: server.hostname,
  				completed: false,
  				date: Time.now.in_time_zone("Pacific Time (US & Canada)")
  			)
  			new_event.save
		end
		
	end

	servers = Server.all
	update_instances_state(servers)
	servers.each do |server|
		if server.state == "pending"
			next
		elsif server.locked
			puts "#{server.hostname} LOCKED"
		elsif in_uptime_range? server
			if server.state != "running" or server.state != "pending"
				if server.start_instance
					i_start_event = EventLog.new(
						eventName: "starting instance", 
						state: 'start_instance',
  						hostname: server.hostname,
  						completed: true,
  						date: Time.now.in_time_zone("Pacific Time (US & Canada)")
  					)
  					i_start_event.save
				end	
			end
			
		else
			unless server.state == "stopping" or server.state == "stopped" or server.state == "terminated"
				puts "#{Time.now}: prepare_to_stop"
				prepare_to_stop server

				# goint to stop server soon
				# add record to event loog "stop in Date.now() + 60 minutes"
				# notify server owner
			end
		end			
	end	

  end

end