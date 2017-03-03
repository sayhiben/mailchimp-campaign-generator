require 'yaml'
require 'gibbon'
require 'awesome_print'
require 'active_support/time'

options = YAML::load_file('.config')

gibbon = Gibbon::Request.new(api_key: options['api_key'], debug: options['debug'])

options['campaign_count'].times do |i|
  date = DateTime.now.beginning_of_day + (options['start_day'] + i)
  begin
    puts "Creating Campaign #{i}"
    response = gibbon.campaigns.create(
      body: {
        type: 'regular',
        recipients: {
          list_id: options['list_id'],
          segment_opts: {
            saved_segment_id: options['segment_id']
          },
        },
        settings: {
          subject_line: "#{options['subject_prefix']} - #{date.strftime('%A, %B %e, %Y')}",
          from_name: options['from_name'],
          reply_to: options['reply_to']
        }
      }
    )
    campaign_id = response.body['id']

    puts "Updating Campaign to use Template #{options['template_id']}"
    gibbon.campaigns(campaign_id).content.upsert(
      body: {
        template: {
          id: options['template_id']
        }
      }
    )

    send_time = date + options['send_time'].hours
    puts "Scheduling Campaign #{i} for #{send_time}"
    gibbon.campaigns(campaign_id).actions.schedule.create(
      body: {
        schedule_time: send_time
      }
    )
  rescue Gibbon::MailChimpError => e
    puts "MailChimp Error: #{e.message} - #{e.raw_body}"
  end
end
