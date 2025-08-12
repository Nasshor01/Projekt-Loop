# res://scripts/debug/PerformanceMonitor.gd
class_name PerformanceMonitor
extends Node

var fps_log_interval: float = 5.0
var fps_timer: Timer
var low_fps_threshold: int = 30
var consecutive_low_fps: int = 0

func _ready():
	# Tento timer je POUZE pro tento skript
	fps_timer = Timer.new()
	fps_timer.wait_time = fps_log_interval
	fps_timer.timeout.connect(_check_performance)
	fps_timer.autostart = true
	add_child(fps_timer)

func _check_performance():
	var current_fps = Engine.get_frames_per_second()
	
	if current_fps < low_fps_threshold:
		consecutive_low_fps += 1
		
		if consecutive_low_fps >= 3:  # 15 sekund nízkého FPS
			DebugLogger.log_warning("Persistent low FPS: %d" % current_fps, "PERFORMANCE")
			# Tyto informace mohou být v Godot 4 mírně odlišné
			# DebugLogger.log_debug("Draw calls: %d" % RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME), "PERFORMANCE")
			DebugLogger.log_debug("Memory: %.2f MB" % (OS.get_static_memory_usage() / 1048576.0), "PERFORMANCE")
	else:
		consecutive_low_fps = 0
