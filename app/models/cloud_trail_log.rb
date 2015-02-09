require 'aws-sdk-core'

class CloudTrailLog
  include Mongoid::Document
  field :event_id, type: String
  field :log_event, type: Hash
  field :event_name, type: String

end
