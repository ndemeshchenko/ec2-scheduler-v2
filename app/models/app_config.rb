class AppConfig
  include Mongoid::Document
  field :events, type: String
end
