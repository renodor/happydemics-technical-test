# frozen_string_literal:true

class Time
  def to_default_strf
    strftime('%Y%m%d%H%M%S')
  end
end
