
require 'telegram/bot'
require 'open-uri'
load    'videostab.rb'
token  = '459256665:AAFdAwtfLljM8l_-OirZQx201rnSUNrIPvw'
width  = 1920
heigth = 1080
track  = false
crop   = 25
Telegram::Bot::Client.run(token, logger: Logger.new('logfile.log'), offset: -1) do |bot|
  begin
  bot.listen do |message|
    p message
    bot.logger.info("Message from user with #{message.from.id}id, f_name=#{message.from.first_name}, l_name=#{message.from.last_name}")
    if message.text
      splitted = message.text.split(' ')
      case splitted[0]
      when '/start'
        bot.api.send_message(chat_id: message.chat.id, text: "Hello, #{message.from.first_name}")
        #Thread.main.run
      when '/stop'
        bot.api.send_message(chat_id: message.chat.id, text: "Bye, #{message.from.first_name}")
        #Thread.main.stop
      when '/help'
        bot.api.send_message(chat_id: message.chat.id, text: 
%{send video and wait for result
MAX video size is 20 Mb
default processed video resolution is 1920x1080
type /resize [width] [heigth] - to change processed video resolution 
type /track to track keypoints of image
type /crop to change cropping borders
type /config to get current settings
})
      when '/resize'
        width = splitted[1]  if splitted[1].to_i > 0
        heigth = splitted[2] if splitted[2].to_i > 0
        bot.logger.info("New video resolution #{width}  #{heigth}")
        bot.api.send_message(chat_id: message.chat.id, text: "Change video resolution, #{width}  #{heigth}")
      when '/track'
        track ^= true
        bot.api.send_message(chat_id: message.chat.id, text: "Features tracking mode on: #{track}")
      when '/crop'
        horizontal_crop = splitted[1] if 0 < splitted[1].to_i && splitted[1].to_i < width
        bot.api.send_message(chat_id: message.chat.id, text: "Cropping borders: #{crop}")
      when '/config'
        bot.api.send_message(chat_id: message.chat.id, text: 
%{size : #{width}x#{heigth}
track mode: #{track}
cropping borders: #{crop}
      })
      else 
        bot.api.send_message(chat_id: message.chat.id, text: "I reversed your message: #{message.text.reverse}") if message.text
      end
    end
    if message.video || message.document
        bot.api.send_message(chat_id: message.chat.id, text: "Video processing started\n ...")     
        file_id = message.document.file_id rescue message.video.file_id
        file    = bot.api.get_file(file_id: file_id)
        file_id, file_size, file_path = file['result'].values
        fmt     = (message.document.mime_type rescue message.video.mime_type).split('/')[-1]
        bot.logger.info("Get file with #{file_id}id, file_path=#{file_path}, format=#{fmt}")
        open("videos/#{file_id}.#{fmt}", 'wb') do |file|
          file <<  open("https://api.telegram.org/file/bot#{token}/#{file_path}").read
        end
        path = "C:\\Users\\George\\Desktop\\ruby_apps\\telegram_videostab\\videos\\%s.%s" % [file_id, fmt]
        bot.logger.info('Start video stabilization')
        Thread.new do
          bot.logger.info('New thread started')  
          videostab(path, "#{width}", "#{heigth}","#{crop}", "#{track.to_s.capitalize}")
          bot.api.send_message(chat_id: message.chat.id, text: "Video processing finished")
          bot.api.send_video(chat_id: message.chat.id, video: Faraday::UploadIO.new("videos/#{file_id}stab.#{fmt}", 'video/mp4'){})
          bot.logger.info("Send stab video")
        end
        p Thread.list
    end
  end
  rescue 
  bot.logger.warn("#{$!}")
  end
end
