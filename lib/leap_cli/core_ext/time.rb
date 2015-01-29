#
# The following methods are copied from ActiveSupport's Time extension:
# activesupport/lib/active_support/core_ext/time/calculations.rb
#

class Time

  #
  # Uses Date to provide precise Time calculations for years, months, and days
  # according to the proleptic Gregorian calendar. The options parameter takes
  # a hash with any of these keys: :years, :months, :weeks, :days, :hours,
  # :minutes, :seconds.
  #
  def advance(options)
    unless options[:weeks].nil?
      options[:weeks], partial_weeks = options[:weeks].divmod(1)
      options[:days] = options.fetch(:days, 0) + 7 * partial_weeks
    end

    unless options[:days].nil?
      options[:days], partial_days = options[:days].divmod(1)
      options[:hours] = options.fetch(:hours, 0) + 24 * partial_days
    end

    d = to_date.advance(options)
    d = d.gregorian if d.julian?
    time_advanced_by_date = change(:year => d.year, :month => d.month, :day => d.day)
    seconds_to_advance = options.fetch(:seconds, 0) +
                         options.fetch(:minutes, 0) * 60 +
                         options.fetch(:hours, 0) * 3600

    if seconds_to_advance.zero?
      time_advanced_by_date
    else
      time_advanced_by_date.since(seconds_to_advance)
    end
  end

  def since(seconds)
    self + seconds
  rescue
    to_datetime.since(seconds)
  end

  #
  # Returns a new Time where one or more of the elements have been changed
  # according to the options parameter. The time options (:hour, :min, :sec,
  # :usec) reset cascadingly, so if only the hour is passed, then minute, sec,
  # and usec is set to 0. If the hour and minute is passed, then sec and usec
  # is set to 0. The options parameter takes a hash with any of these keys:
  # :year, :month, :day, :hour, :min, :sec, :usec.
  #
  def change(options)
    new_year  = options.fetch(:year, year)
    new_month = options.fetch(:month, month)
    new_day   = options.fetch(:day, day)
    new_hour  = options.fetch(:hour, hour)
    new_min   = options.fetch(:min, options[:hour] ? 0 : min)
    new_sec   = options.fetch(:sec, (options[:hour] || options[:min]) ? 0 : sec)
    new_usec  = options.fetch(:usec, (options[:hour] || options[:min] || options[:sec]) ? 0 : Rational(nsec, 1000))

    if utc?
      ::Time.utc(new_year, new_month, new_day, new_hour, new_min, new_sec, new_usec)
    elsif zone
      ::Time.local(new_year, new_month, new_day, new_hour, new_min, new_sec, new_usec)
    else
      ::Time.new(new_year, new_month, new_day, new_hour, new_min, new_sec + (new_usec.to_r / 1000000), utc_offset)
    end
  end

end

class Date

  # activesupport/lib/active_support/core_ext/date/calculations.rb
  def advance(options)
    options = options.dup
    d = self
    d = d >> options.delete(:years) * 12 if options[:years]
    d = d >> options.delete(:months)     if options[:months]
    d = d +  options.delete(:weeks) * 7  if options[:weeks]
    d = d +  options.delete(:days)       if options[:days]
    d
  end

end
