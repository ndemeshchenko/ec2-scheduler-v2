every 5.minute do
  rake "scheduler:check", :output => '~/ec2_scheduler.log'
end

# Use this file to easily define all of your cron jobs.
#
# It's helpful, but not entirely necessary to understand cron before proceeding.
# http://en.wikipedia.org/wiki/Cron

# Example:
#
# set :output, "/path/to/my/cron_log.log"
#
# every 2.hours do
#   command "/usr/bin/some_great_command"
#   runner "MyModel.some_method"
#   rake "some:great:rake:task"
# end
#
# every 4.days do
#   runner "AnotherModel.prune_old_records"
# end

# Learn more: http://github.com/javan/whenever

# Begin Whenever generated tasks for: /Users/neveragny/projects/ec2_v2/config/schedule.rb
/bin/bash -l -c 'cd /opt/opt/ec2-scheduler-v2 && RAILS_ENV=development bundle exec rake scheduler:check >> ~/ec2_scheduler.log 2>&1'