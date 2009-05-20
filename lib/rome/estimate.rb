module Rome
  class Estimate

    HOURS_PATTERN = /^#e(\d{2}:\d{2})$/i

    attr_accessor :time, :created_at

    def initialize(time, created_at)
      @time = time
      @created_at = created_at
    end

    # in SI-units! Nice Smn! I like.
    def to_i
      ((@time.hour * 60) + @time.min) * 60
    end

    def self.from_version(version)
      if version.body =~ Rome::Estimate::HOURS_PATTERN
        Estimate.new(Time.parse($1), version.created_at)
      end
    end
  end
end