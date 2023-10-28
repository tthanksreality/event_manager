# frozen_string_literal: true

require 'csv'
require 'google/apis/civicinfo_v2'
require 'erb'
require 'date'

def clean_zipcode(zipcode)
  zipcode.to_s.rjust(5, '0')[0..4]
end

def clean_phone_number(phone_number)
  phone_number.gsub!(/[^\d]/, '')
  if phone_number.length == 10
    phone_number
  elsif phone_number.length == 11 && phone_number[0] == '1'
    phone_number[1..10]
  else
    'Wrong number'
  end
end

def most_frequent_hour(hours)
  counts = Hash.new(0)
  hours.each { |hour| counts[hour] += 1 }
  counts.max_by { |_hour, count| count }.first
end

def most_frequent_day(days)
  day = days.group_by(&:itself).values.max_by(&:size).first

  case day
  when 0 then 'Sunday'
  when 1 then 'Monday'
  when 2 then 'Tuesday'
  when 3 then 'Wednesday'
  when 4 then 'Thursday'
  when 5 then 'Friday'
  when 6 then 'Saturday'
  end
end

def legislators_by_zipcode(zip)
  civic_info = Google::Apis::CivicinfoV2::CivicInfoService.new
  civic_info.key = 'AIzaSyClRzDqDh5MsXwnCWi0kOiiBivP6JsSyBw'

  begin
    civic_info.representative_info_by_address(
      address: zip,
      levels: 'country',
      roles: %w[legislatorUpperBody legislatorLowerBody]
    ).officials
  rescue StandardError
    'You can find your representatives by visiting www.commoncause.org/take-action/find-elected-officials'
  end
end

def save_thank_you_letter(id, form_letter)
  Dir.mkdir('../output') unless Dir.exist?('../output')

  filename = "../output/thanks_#{id}.html"

  File.open(filename, 'w') do |file|
    file.puts form_letter
  end
end

puts 'EventManager initialized.'

contents = CSV.open(
  '../event_attendees.csv',
  headers: true,
  header_converters: :symbol
)

template_letter = File.read('../form_letter.erb')
erb_template = ERB.new template_letter

hours_arr = []
week_days = []

contents.each do |row|
  id = row[0]
  name = row[:first_name]

  zipcode = clean_zipcode(row[:zipcode])

  phone_number = clean_phone_number(row[:homephone])

  reg_date = row[:regdate]
  formatted_date = DateTime.strptime(reg_date, '%m/%d/%y %H:%M')
  hours_arr.push(formatted_date.hour)
  week_days.push(formatted_date.wday)
  legislators = legislators_by_zipcode(zipcode)

  form_letter = erb_template.result(binding)
  save_thank_you_letter(id, form_letter)
end

puts "Most active  hour is : #{most_frequent_hour(hours_arr)}"
puts "Most active  day is : #{most_frequent_day(week_days)}"
