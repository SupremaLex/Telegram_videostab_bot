require 'telegram/bot'
require 'open-uri'
require_relative  './videostab'

# VideostabBot is a telegram bot that stabilizes the video
# example:
# token = 'XXXXXXXXXXXXXX'
# bot = VideostabBot.new(token)
# bot.start_bot
class VideostabBot

	# default settings
	WIDTH  	  = 1920
	HEIGHT 	  = 1080
	TRACKING  = false
	CROP   	  = 25

	# Initialize VideostabBot object with configurating params
	# @param token[String]
	# @return nil
	def initialize(token)
		@bot = Telegram::Bot::Client.new(token, logger: Logger.new('logfile.log'), offset: -1)
		@token = token
		@width = WIDTH
		@height = HEIGHT
		@tracking = TRACKING
		@crop_borders = CROP
	end

	# Execute a command
	# @param message[Telegram::Bot::Types::Message]
	# @return nil
	def exec_command(message)
		command, *params = message.text.split(' ')
		chat_id = message.chat.id
		case command
		when '/start'
			bot.api.send_message(chat_id: chat_id, text: "Hello, #{message.from.first_name}")
		when '/stop'
			bot.api.send_message(chat_id: chat_id, text: "Bye, #{message.from.first_name}")
		when '/help'
			help chat_id
		when '/resize'
			resize chat_id, params
		when '/track'
			track chat_id
		when '/crop'
			crop chat_id, params
		when '/config'
			config chat_id
		end
	end
	# help command : send list of all commands and theit description
	# @params chat_id[String] chat_id from Telegram::Bot::Types::Chat
	# @return nil
	def help(chat_id)
		bot.api.send_message(chat_id: chat_id, text: 
%{send video and wait for result
MAX video size is 20 Mb
default processed video resolution is 1920x1080
type /resize [width] [heigth] - to change processed video resolution 
type /track to track keypoints of image
type /crop to change cropping borders
type /config to get current settings
})
	end

	# resize command: resize the processed video size and send current size to the chat
	# @param chat_id[String] chat_id from Telegram::Bot::Types::Chat
	# @param params[Array[Integer]] optional params, which determine processed video size
	# @return nil
	def resize(chat_id, *params)
		@width = params[1]  if params[1].to_i > 0
		@heigth = params[2] if params[2].to_i > 0
		bot.logger.info("New video resolution #{@width}  #{@height}")
		bot.api.send_message(chat_id: chat_id, text: "Change video resolution, #{@width}  #{@heigth}")
	end

	# track command: change tracking features status (track or not to track keypoints) and send current status to the chat
	# each call of this method change status to opposite
	# @param chat_id[String] chat_id from Telegram::Bot::Types::Chat
	# @return nil
	def track(chat_id)
		@tracking ^= true
		bot.api.send_message(chat_id: chat_id, text: "Features tracking mode on: #{@tracking}")
	end

	# crop command: change cropping borders and current cropping borders to the chat
	# @param chat_id[String] chat_id from Telegram::Bot::Types::Chat
	# @param border[Fixnum]
	# @return nil 
	def crop(chat_id, border)
		horizontal_crop = border if 0 < border.to_i && border.to_i < width
		bot.api.send_message(chat_id: chat_id, text: "Cropping borders: #{@crop_borders}")
	end

	# config command: send current configurations to the chat
	# @param chat_id[String] chat_id from Telegram::Bot::Types::Chat
	# @return nil
	def config(chat_id)
		bot.api.send_message(chat_id: chat_id, text: 
%{size : #{@width}x#{@heigth}
track mode : #{@tracking}
cropping borders : #{@crop_borders}
})
	end

	# download video from chat as Telegram::Bot::Types::Document or Telegram::Bot::Types::Video
	# @param message[Telegram::Bot::Types::Message]
	# @return nil
	def get_video(message)
		begin 
			file_id = message.document.file_id rescue message.video.file_id
			file    = bot.api.get_file(file_id: file_id)
			file_id, file_size, file_path = file['result'].values
			type, *other, fmt = (message.document.mime_type rescue message.video.mime_type).split('/')
			if type != 'video'
				bot.api.send_message(chat_id: message.chat.id, text: "Send video, please")
			end
			bot.logger.info("Get file with #{file_id}id, file_path=#{file_path}, format=#{fmt}")
			open("videos/#{file_id}.#{fmt}", 'wb') do |file|
				file <<  open("https://api.telegram.org/file/bot#{@token}/#{file_path}").read
			end
			bot.api.send_message(chat_id: message.chat.id, text: "Video processing started\n ...")  
			bot.logger.info('Start video stabilization')
			path = "C:\\Users\\George\\Desktop\\ruby_apps\\telegram_videostab\\videos\\%s.%s" % [file_id, fmt]
			rescue
				p $!
				retry
			end
	end

	# process video via python script calling and send processed video to chat
	# @param path[String] path to video
	# @param chat_id[String] chat_id from Telegram::Bot::Types::Chat
	# @return nil
	def process_video(path, chat_id)
			bot.logger.info('New thread started')
			# call python script with current configuration  
			videostab(path, "#{@width}", "#{@height}", "#{@crop_borders}", "#{@tracking.to_s.capitalize}")
			bot.api.send_message(chat_id: chat_id, text: "Video processing finished")
			path, fmt = path.split('.')
			new_video_path = path + 'stab.' + fmt
			bot.api.send_video(chat_id: chat_id, video: Faraday::UploadIO.new(new_video_path, 'video/'+fmt))
			bot.logger.info("Send stab video")
	end

	# start bot
	# get updates from chat until Signal INT send 
	def start_bot		
		@bot.run do |bot|
			bot.listen do |message|
				exec_command(message) if message.text
				if message.video || message.document
					path = get_video(message)
					# process video in new thread
					Thread.new {process_video(path, message.chat.id)}
				end
				# the maximum number of thread is 4, if there are 4 threads
				if Thread.list.length > 4
					@bot.logger.info("Too much threads")
					# wait for all thread joined
					Thread.list[1..-1].each {|thread| thread.join}
				end
			end
		end
	end


end