class EventLog
  include Mongoid::Document
  field :eventName, type: String
  field :state, type: String
  field :hostname, type: String
  field :comment, type: String
  field :completed, type: Mongoid::Boolean
  field :date, type: DateTime
end
