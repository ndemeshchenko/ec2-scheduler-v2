require 'aws-sdk-core'

class CloudTrailLog
  include Mongoid::Document
  field :event_id, type: String
  field :log_event, type: String
  field :event_name, type: String

end
