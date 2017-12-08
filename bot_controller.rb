
class BotController

	WIDTH  	  = 1920
	HEIGTH 	  = 1080
	TRACKING  = false
	CROP   	  = 25

	attr_reader :width, :height, :tracking, :crop_borders

	def initialize(token)
		@bot = Telegram::Bot::Client.new(token, logger: Logger.new('logfile.log'))
		@width = WIDTH
		@height = HEIGTH
		@tracking = TRACKING
		@crop_borders = CROP
	end

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

	def resize(chat_id, *params)
		@width = params[1]  if params[1].to_i > 0
		@heigth = params[2] if params[2].to_i > 0
		bot.logger.info("New video resolution #{@width}  #{@heigth}")
		bot.api.send_message(chat_id: chat_id, text: "Change video resolution, #{@width}  #{@heigth}")
	end

	def track(chat_id)
		@tracking ^= true
		bot.api.send_message(chat_id: chat_id, text: "Features tracking mode on: #{@tracking}")
	end

	def crop(chat_id, *params)
		horizontal_crop = params[0] if 0 < params[0].to_i && params[0].to_i < width
		bot.api.send_message(chat_id: chat_id, text: "Cropping borders: #{@crop_borders}")
	end

	def config(chat_id)
		bot.api.send_message(chat_id: chat_id, text: 
%{size : #{@width}x#{@heigth}
track mode : #{@tracking}
cropping borders : #{@crop_borders}
})
	end

	def get_video(message)
		bot.api.send_message(chat_id: message.chat.id, text: "Video processing started\n ...")     
		file_id = message.document.file_id rescue message.video.file_id
		file    = bot.api.get_file(file_id: file_id)
		file_id, file_size, file_path = file['result'].values
		fmt     = (message.document.mime_type rescue message.video.mime_type).split('/')[-1]
		bot.logger.info("Get file with #{file_id}id, file_path=#{file_path}, format=#{fmt}")
		open("videos/#{file_id}.#{fmt}", 'wb') do |file|
			file <<  open("https://api.telegram.org/file/bot#{token}/#{file_path}").read
		end
		bot.logger.info('Start video stabilization')
		path = "C:\\Users\\George\\Desktop\\ruby_apps\\telegram_videostab\\videos\\%s.%s" % [file_id, fmt]
	end

	def process_video(path, chat_id)
		Thread.new do
			bot.logger.info('New thread started')  
			videostab(path, "#{@width}", "#{@heigth}","#{@crop_borders}" "#{@tracking.to_s.capitalize}")
			bot.api.send_message(chat_id: chat_id, text: "Video processing finished")
			path = path.split('.')
			new_video_path = path[0] + 'stab' + path[1]
			bot.api.send_video(chat_id: chat_id, video: Faraday::UploadIO.new(new_video_path, 'video/'+path[1]))
			bot.logger.info("Send stab video")
		end
	end

	def start_bot
		@bot.run do |bot|
			bot.listen do |message|
				exec_command(message) if message.text
				if message.video || message.document
					path = get_video(message)
					Thread.new {process_video(path, message.chat.id)} 
				end
			end
		end
	end

	def stop_bot
		for thread in Thread.list
			thread.kill
		end
		Thread.main.stop
	end
end