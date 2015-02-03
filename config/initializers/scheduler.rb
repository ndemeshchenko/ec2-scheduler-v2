require 'rufus-scheduler'
require 'pry'
require 'aws-sdk-core'
require 'json'
require 'curb'
require 'nokogiri'

scheduler = Rufus::Scheduler.singleton

scheduler.every '1m' do
	main
end

@ec2 = Aws::EC2::Client.new(region:'us-east-1')
@ses = Aws::SES::Client.new(region:'us-east-1')
@notification_queue = []

def in_uptime_range?(server)
	now = Time.now
	day_of_week = now.wday
	schedule_days = server.schedule_days.split(',')
	schedule_hours = server.schedule_hours.split('-')
	if schedule_days.include? now.strftime("%a")
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

def send_email(servers)
	hibernation_notification_template_servers = []
	servers.each do |server|
		time = Time.now + server.notification_interval.to_i.minutes
		hibernation_notification_template_servers << "#{server.hostname} @ #{time.strftime("%H")}:#{time.strftime("%M")}<p><p>To cancel this hibernation, go to <a href='http://snoopy.escm.co:3000/servers/#{server.id.to_s}/edit'>http://snoopy.escm.co/servers/#{server.id.to_s}/edit</a>"
	end
	hibernation_notification_template = "The following servers are scheduled to go down for hibernation:<p>" + 
										hibernation_notification_template_servers.join("<p>--<p>") +
										# "<p><p>To wake up instances already hibernating, go to TBD<SOMETHING APPROPRIATE HERE> " + ""				
										"<p><p>Thanks,<p>EngOps Bot"
	ses_resp = @ses.send_email(
		source: "ec2-scheduler@elementum.com",
		destination: {
		to_addresses: servers.map { |server| server.notification_list.split }.flatten.uniq,
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
	puts "message send to #{ses_resp['message_id']} "
end

def set_nagios_downtime(server)
	nagios_url = "http://nagios.elementums.com"
	nagios_cmd_uri = "/cgi-bin/nagios3/cmd.cgi"
	nagios_host = server.url
	c = Curl::Easy.http_post("#{nagios_url}#{nagios_cmd_uri}",
								Curl::PostField.content('cmd_typ', '55'),
								Curl::PostField.content('cmd_mod', '2'),
								Curl::PostField.content('host', nagios_host),
								Curl::PostField.content('com_data', "downtime by EC2 Scheduler - #{server.hostname}"),
								Curl::PostField.content('trigger', '0'),
								Curl::PostField.content('start_time', Time.now.utc.strftime("%Y-%m-%d %H:%M:%S")),
								Curl::PostField.content('end_time', (Time.now.utc + 8.hours).strftime("%Y-%m-%d %H:%M:%S")),
								Curl::PostField.content('fixed', '1'),
								Curl::PostField.content('hours', '8'),
								Curl::PostField.content('minutes', '0'),
								Curl::PostField.content('btnSubmit', 'Commit')
							)
	c.http_auth_types = :basic
	c.username = 'ndemeshchenko'
	c.password = 'rpiffwhz'
	c.perform
end

def cancel_nagios_downtime(server)
	nagios_url="http://nagios.elementums.com/cgi-bin/nagios3/extinfo.cgi?type=6"
	nagios_host = server.url
	c = Curl::Easy.new(nagios_url)
	c.http_auth_types = :basic
	c.username = 'ndemeshchenko'
	c.password = 'rpiffwhz'
	c.perform
	html_doc = Nokogiri::HTML(c.body)
	html_doc.css("a[href*='extinfo.cgi?type=1&host=']").each do |element|
		if element.text == server.url
			puts "CANCEL NAGIOS DOWNTIME for #{server.url}"
			cancel_link = element.parent.parent.css("a[href*='cmd.cgi']").first.attributes['href'].value
			c_nagios = Curl::Easy.http_post("http://nagios.elementums.com/cgi-bin/nagios3/cmd.cgi",
										Curl::PostField.content('cmd_typ', '78'),
										Curl::PostField.content('cmd_mod', '2'),
										Curl::PostField.content('down_id', cancel_link.split('=').last),
										Curl::PostField.content('btnSubmit', 'Commit'))
			c_nagios.http_auth_types = :basic
			c_nagios.username = 'ndemeshchenko'
			c_nagios.password = 'rpiffwhz'
			c_nagios.perform	
		end
	end
end

def stop_instance(server)
	unless Server.where(instance_id: server.instance_id).first.locked
		puts "going to stop instance. NO KIDDING HERE"

			#clear uncompleted event
		event = EventLog.where(state: 'notification', hostname: server.hostname, completed: false).first
		event.completed = true
		event.save

		set_nagios_downtime(server)
		resp = @ec2.stop_instances(
			dry_run: false,
			instance_ids: [server.instance_id]
		)

		server = Server.where(instance_id: server.instance_id).first
		server.state = resp.first.stopping_instances[0].current_state.name
		server.save

		new_event = EventLog.new(
			eventName: 'instance has been stopped', 
			state: 'stopInstance',
  			hostname: server.hostname,
  			completed: true,
  			date: Time.now.in_time_zone("Pacific Time (US & Canada)")
  		)
  		new_event.save
	end
end

def prepare_to_stop(server)
	events = EventLog.where(hostname: server.hostname, state: "notification", completed: false)
	log_date = events[0].date.in_time_zone("Pacific Time (US & Canada)") if events[0]
	log_date_plus_hour = log_date + server.notification_interval.to_i.minutes if events[0] # add 1 minute
	if events.size > 0
		if (log_date_plus_hour < Time.now.in_time_zone("Pacific Time (US & Canada)"))
			stop_instance server;
		end
	else
		puts("instance "+ server.hostname + " scheduled to stop at: #{Time.now + server.notification_interval.to_i.minutes}");
		@notification_queue << server
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

def main
	servers = Server.all
	update_instances_state(servers)
	servers.each do |server|
		if server.state == "pending"
			next
		elsif server.locked
			puts "#{server.hostname} Scheduling disabled"
			next
		elsif in_uptime_range? server
			if server.state != "running" and server.state != "pending"
				puts server.state
				if server.start_instance
					cancel_nagios_downtime(server)
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
			end
		end
	end
	if @notification_queue.size > 0
		send_email(@notification_queue)
		@notification_queue.clear
	end
end


