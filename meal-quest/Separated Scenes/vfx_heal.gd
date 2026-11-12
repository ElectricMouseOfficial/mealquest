#extends Node2D
### Variables
#var radius:float = 
#var angle:float = 
#var speed:float = 

#@export var _X_OFFSET =
#@export var _Y_OFFSET = 
### position.y = pow(position.x,2)
#func _process(delta):
	#circular_motion()

#func circular_motion():
	### Need to make radius shrink and opacity grow over time, don't know how - add timer
	#angle += speed * get_process_delta_time()
	#var x_pos = cos(angle)
	#var y_pos = sin(angle)
	
	#position.x = radius * x_pos + _X_OFFSET
	#position.y = radius * y_pos + _Y_OFFSET
	
	
