PYNAME = 'C:\Users\George\Desktop\PyProjects\main.py'

# call python script which process video and save it in the same dir as original video
# @param path_to_video[String] 
# @param width[Integer] processed video width
# @param height[Integer] processed video height
# @param crop[Integer] cropping borders value
# @param tracking_mode[Boolean] tracking of keypoint mode
def videostab(path_to_video, width, height, crop, tracking_mode)
	# from true/false to 1/0
	tracking_mode  = tracking_mode && 1 || 0
	python_output =  `python #{PYNAME} #{path_to_video} #{width} #{height} #{crop} #{tracking_mode}`
	puts "The output from #{PYNAME} is: #{python_output}"
end
