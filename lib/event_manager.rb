# frozen_string_literal: true

require 'csv'
require 'erb'
require 'google/apis/civicinfo_v2'
require 'time'
require 'date'
require 'open-uri'

BASE_URL = 'https://chart.googleapis.com/chart?cht=bvs&chs=500x300&chma=20,0,0,20&chco=3434eb&chxt=x,y&chxr=1,0,10,1&chbh=a,15'

def draw_chart(data_hash, data_type)
  frequency = []
  hour = []
  data_hash.each do |key, value|
    hour << key
    frequency << value * 10
  end
  chart_hour = "&chxl=0:|#{hour.join('|')}"
  chart_frequency = "&chd=t:#{frequency.join(',')}"
  puts BASE_URL + chart_hour + chart_frequency
  chart_image = URI.open(BASE_URL + chart_hour + chart_frequency).read
  Dir.mkdir('../analyzed_data') unless Dir.exist?('../analyzed_data')
  File.open("../analyzed_data/#{data_type}.png", 'w') { |file| file.write chart_image}
end

def clean_zipcode(zipcode)
  zipcode.to_s.rjust(5, '0')[0..4]
end

def clean_phone_number(phone_number)
  if phone_number.size == 10
    phone_number
  elsif phone_number.size == 11 && phone_number[0] == '1'
    phone_number.sub('1', '')
  end
end

def count(count_hash, being_count)
  count_hash[being_count] += 1 if count_hash[being_count]
  count_hash[being_count] = 1 unless count_hash[being_count]
  count_hash
end

def legislators_by_zipcode(zipcode)
  civic_info = Google::Apis::CivicinfoV2::CivicInfoService.new
  civic_info.key = 'AIzaSyClRzDqDh5MsXwnCWi0kOiiBivP6JsSyBw'

  begin
    civic_info.representative_info_by_address(
      address: zipcode,
      levels: 'country',
      roles: %w[legislatorUpperBody legislatorLowerBody]
    ).officials
  rescue StandardError
    'You can find your representatives by visiting www.commoncause.org/take-action/find-elected-officials'
  end
end

def save_thank_you_letter(id, form_letter, phone_number = nil)
  Dir.mkdir('../output') unless Dir.exist?('../output')
  filename = "../output/#{id}.html"
  File.open(filename, 'w') do |file|
    file.puts form_letter
  end
  save_thank_you_letter(phone_number, form_letter) if phone_number
end

puts 'Event Manager Initialized!'

content = CSV.open(
  'event_attendees.csv',
  headers: true,
  header_converters: :symbol
)

template_letter = File.read('../form_letter.erb')
erb_template = ERB.new template_letter
hours_counted = {}
days_counted = {}


content.each do |row|
  id = row[0]
  name = row[:first_name]

  time = Time.strptime(row[:regdate], '%m/%d/%Y %k:%M') 
  hour = time.hour
  hours_counted = count(hours_counted, hour)

  day = time.strftime("%A")
  days_counted = count(days_counted, day)

  phone_number = clean_phone_number(row[:homephone])

  zipcode = clean_zipcode(row[:zipcode])

  legislators = legislators_by_zipcode(zipcode)

  form_letter = erb_template.result(binding)

  save_thank_you_letter(id, form_letter, phone_number)
end

hours_counted = hours_counted.to_a.sort { |a, b| a[0] - b[0] }.to_h

days_counted = Date::DAYNAMES.inject({}) do |hash, day|
  hash[day] = days_counted[day] ? days_counted[day] : 0
  hash
end

draw_chart(hours_counted, 'hour')
draw_chart(days_counted, 'day')