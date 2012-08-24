# AirCasting - Share your Air!
# Copyright (C) 2011-2012 HabitatMap, Inc.
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
# You can contact the authors by email at <info@habitatmap.org>

class Measurement < ActiveRecord::Base
  self.skip_time_zone_conversion_for_attributes = [:time]

  include AirCasting::FilterRange

  Y_SIZES = (1..300).map { |i| 1.2 ** i * 0.000001 }
  SECONDS_IN_MINUTE = 60

  # belongs_to :session, :through => :stream, :inverse_of => :measurements, :counter_cache => true
  belongs_to :stream, :inverse_of =>:measurements, :counter_cache => true
  has_one :session, :through => :stream
  has_one :user, :through => :session

  validates :stream, :value, :longitude, :latitude, :time, :presence => true

  prepare_range(:longitude_range, :longitude)
  prepare_range(:latitude_range, :latitude)
  prepare_range(:time_range, "(EXTRACT(HOUR FROM time) * 60 + EXTRACT(MINUTE FROM time))")
  prepare_range(:day_range, "(DAYOFYEAR(time))")
  prepare_range(:year_range, :time)

  geocoded_by :address # field doesn't exist, call used for .near scope inclusion only

  before_validation :set_timezone_offset

  def self.averages(data)
    if data[:west] < data[:east]
      grid_x = (data[:east] - data[:west]) / data[:grid_size_x]
    else
      grid_x = (180 - data[:west] + 180 + data[:east]) / data[:grid_size_x]
    end

    grid_y = (data[:north] - data[:south]) / data[:grid_size_y]
    grid_y = Y_SIZES.find { |x| x > grid_y }

    measurements =
      joins(:session).
      joins(:stream).
      select(
        "GROUP_CONCAT(sessions.id) as ids, AVG(value) AS avg, " +
          "round(CAST(longitude AS DECIMAL(36, 12)) / CAST(#{grid_x} AS DECIMAL(36,12)), 0) AS middle_x, " +
          "round(CAST(latitude AS DECIMAL(36, 12)) / CAST(#{grid_y} AS DECIMAL(36,12)), 0) AS middle_y "
      ).
        where(:sessions => { :contribute => true }).
        where(:streams =>  { :measurement_type => data[:measurement_type], :sensor_name => data[:sensor_name] }).
        group("middle_x").
        group("middle_y").
        longitude_range(data[:west], data[:east]).
        latitude_range(data[:south], data[:north]).
        time_range(data[:time_from], data[:time_to]).
        day_range(data[:day_from], data[:day_to])

    if data[:year_to] && data[:year_from]
      year_range(Date.new(data[:year_from]), Date.new(data[:year_to]))
    end

    tags = data[:tags].to_s.split(/[\s,]/)
    if tags.present?
      sessions_ids = Session.select("sessions.id").tagged_with(tags).map(&:id)
      if sessions_ids.present?
        measurements = measurements.where(:streams => {:session_id => sessions_ids})
      else
        measurements = []
      end
    end

    usernames = data[:usernames].to_s.split(/[\s,]/)
    if usernames.present?
      measurements = measurements.joins(:session => :user).where(:users => {:username =>  usernames})
    end

    measurements.map do |measurement|
      {
        :ids => measurement.ids,
        :value => measurement.avg.to_f,
        :west  =>  measurement.middle_x.to_f * grid_x - grid_x / 2,
        :east  =>  measurement.middle_x.to_f * grid_x + grid_x / 2,
        :south  =>  measurement.middle_y.to_f * grid_y - grid_y / 2,
        :north  =>  measurement.middle_y.to_f * grid_y + grid_y / 2
      }
    end
  end

  def set_timezone_offset
    if time_before_type_cast
      self.timezone_offset = time_before_type_cast.to_datetime.utc_offset / SECONDS_IN_MINUTE
    end
  end
end
