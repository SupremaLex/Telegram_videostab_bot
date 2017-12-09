PYNAME = 'C:\Users\George\Desktop\PyProjects\main.py'
def videostab(path_to_video, width, height, crop, tracking_mode)
	p path_to_video
	#File.open(PYNAME, 'w'){|f| f.write(%{from videostab import video_stab
#video_stab(r'#{path_to_video}', new_size=(#{width}, #{height}),crop=#{crop}, tracking_mode=#{tracking_mode})})
	#}
	tracking_mode  = tracking_mode && 1 || 0
	python_output =  `python #{PYNAME} #{path_to_video} #{width} #{height} #{crop} #{tracking_mode}`
	puts "The output from #{PYNAME} is: #{python_output}"
end
