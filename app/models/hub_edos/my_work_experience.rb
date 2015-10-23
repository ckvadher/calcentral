module HubEdos
  class MyWorkExperience < UserSpecificModel

    include ClassLogger
    include Cache::LiveUpdatesEnabled
    include Cache::FreshenOnWarm
    include Cache::JsonAddedCacher

    def get_feed_internal
      HubEdos::WorkExperience.new({user_id: @uid}).get
    end

  end
end