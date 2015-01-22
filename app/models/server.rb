class Server
  include Mongoid::Document
  field :instance_id, type: String
  field :hostname, type: String
  field :url, type: String
  field :state, type: String
  field :schedule_days, type: String
  field :schedule_hours, type: String
  field :locked, type: Mongoid::Boolean
end
