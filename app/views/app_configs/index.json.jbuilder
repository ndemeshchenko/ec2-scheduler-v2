json.array!(@app_configs) do |app_config|
  json.extract! app_config, :id, :events
  json.url app_config_url(app_config, format: :json)
end
