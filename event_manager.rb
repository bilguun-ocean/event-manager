require 'csv'
require 'erb'
require 'time'
require 'google/apis/civicinfo_v2'

#NOTE: After you are done with the functionality
#refactor the code so it can be used without global variables and
#turn the related variables, methods into a single general variables


def clean_zipcode(zipcode)
  zipcode.to_s.rjust(5, '0')[0..4]
end

def legislators_by_zipcode(zipcode)
  civic_info = Google::Apis::CivicinfoV2::CivicInfoService.new
  civic_info.key = 'AIzaSyClRzDqDh5MsXwnCWi0kOiiBivP6JsSyBw'
  begin
    legislators = civic_info.representative_info_by_address(
      address: zipcode,
      levels: 'country',
      roles: ['legislatorUpperBody', 'legislatorLowerBody']
    ).officials
  rescue
    'You can find your representatives by visiting www.commoncause.org/take-action/find-elected-officials'
  end
end

def save_thank_you_letter(id, form_letter)
  Dir.mkdir('output') unless Dir.exists?('output')

  filename = "output/thanks_#{id}.html"

  File.open(filename, 'w') do |file|
    file.puts form_letter
  end 
end

def check_phone_number(number, result_array)
  if number.length == 10
    result_array[0].push(number)
  elsif number.length == 11
    if number[0] == '1'
      #if starting with 1 deletes front number and returns rest
      result_array[0].push(number[1,11])
    else
      result_array[1].push(number)
    end
  else
    result_array[1].push(number)
  end
end

def output_phone_numbers(array, output_file)
  output_file.puts 'Good numbers: '
  output_file.puts array[0]
  output_file.puts 'Bad numbers: '
  output_file.puts array[1]
end

# here combine both collect
def collect_registration_dates(result, input)
  hour = Time.strptime("#{input}", "%m/%d/%Y %k:%M").hour
  day = Time.strptime("#{input}", "%m/%d/%Y %k:%M").wday

  result[0][hour] += 1
  result[1][day] += 1
end

def sort_registration_dates_by_instances(registration_dates)
  #
  registration_dates[0] = registration_dates[0].sort_by {|pair| pair[1]}.reverse.to_h
  registration_dates[1] = registration_dates[1].sort_by {|pair| pair[1]}.reverse.to_h
end

def output_peak_registration_dates(registration_dates, output_file)
  sort_registration_dates_by_instances(registration_dates)
  give_letter_name_to_weekdays(registration_dates)
  output_file.puts "Peak registration hours are: "
  registration_dates[0].each do |pair|
    output_file.puts "#{pair[1]} people was registered from #{pair[0]}:00 to #{pair[0]}:59"
  end
  output_file.puts "Peak registration days are: "
  registration_dates[1].each do |pair|
    output_file.puts "#{pair[1]} number of people was registered on #{pair[0]}"
  end

end

def give_letter_name_to_weekdays (registration_dates)
  result = [] 
  registration_dates[1].each do |key, value|
    key = case key
    when 0
      "Sunday"
    when 1
      "Monday"
    when 2
      "Tuesday"
    when 3
      "Wednesday"
    when 4
      "Thursday"
    when 5
      "Friday"
    when 6
      "Saturday"
    end

    result.push([key, value])
  end

  registration_dates[1] = result.to_h
end


puts 'EventManager initialized.'

contents = CSV.open(
  'event_attendees.csv',
   headers: true,
   header_converters: :symbol
  )

template_letter = File.read('form_letter.erb')
erb_template = ERB.new template_letter
phone_file = File.open('phone.txt', 'w')
phone_array = [ [], [] ]
registration_dates = [ Hash.new(0), Hash.new(0)]
peak_registered_days_and_hours = File.open('peak_registration.txt', 'w')


contents.each do |row|
  #Think about using regex here.
  phone_number = row[5].delete(' ().+-')
  id = row[0]
  registered_date = row[1]
  name = row[:first_name]

  zipcode = clean_zipcode(row[:zipcode])

  legislators = legislators_by_zipcode(zipcode)

  form_letter = erb_template.result(binding)
  save_thank_you_letter(id, form_letter)

  check_phone_number(phone_number, phone_array)
  
  collect_registration_dates(registration_dates, registered_date)

  
end


output_phone_numbers(phone_array, phone_file)
output_peak_registration_dates(registration_dates, peak_registered_days_and_hours)
p registration_dates[0]
p registration_dates[1]


puts 'EventManager has been finished'




