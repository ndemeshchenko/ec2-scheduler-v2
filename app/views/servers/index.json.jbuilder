json.array!(@servers) do |server|
  json.extract! server, :id, :instance_id, :hostname, :url, :state, :schedule_days, :schedule_hours, :locked
  json.url server_url(server, format: :json)
end
