# res://scripts/debug/CrashReporter.gd
class_name CrashReporter
extends Node

# Tato třída obsahuje pouze statické funkce, nevytváří se z ní instance.

static func generate_crash_report(error_msg: String) -> String:
	var report = []
	report.append("=== CRASH REPORT ===")
	report.append("Time: %s" % Time.get_datetime_string_from_system())
	report.append("Error: %s" % error_msg)
	report.append("")
	report.append("=== SYSTEM ===")
	report.append("Godot: %s" % Engine.get_version_info().string)
	report.append("OS: %s" % OS.get_name())
	report.append("Memory: %.2f MB" % (OS.get_static_memory_usage() / 1048576.0))
	report.append("")
	report.append("=== GAME STATE ===")
	if PlayerData:
		report.append("HP: %d/%d" % [PlayerData.current_hp, PlayerData.max_hp])
		report.append("Floor: %d" % (PlayerData.floors_cleared + 1))
		report.append("Cards in deck: %d" % PlayerData.master_deck.size())
		if not PlayerData.artifacts.is_empty():
			report.append("Artifacts:")
			for artifact in PlayerData.artifacts:
				if is_instance_valid(artifact):
					report.append("  - %s" % artifact.artifact_name)
	if GameManager and GameManager.current_scene:
		report.append("Current scene: %s" % GameManager.current_scene.name)
	report.append("")
	report.append("=== STACK TRACE ===")
	var stack = get_stack()
	for frame in stack:
		report.append("  %s:%d in %s()" % [frame.source, frame.line, frame.function])
	report.append("=== END CRASH REPORT ===")
	var report_text = "\n".join(report)
	var crash_file = FileAccess.open("user://crash_report_%s.txt" % Time.get_unix_time_from_system(), FileAccess.WRITE)
	if crash_file:
		crash_file.store_string(report_text)
	DebugLogger.log_info("Crash report generated.", "CRASH")
	if DebugLogger and DebugLogger.has_method("send_crash_report_to_discord"):
		DebugLogger.send_crash_report_to_discord(report_text)
	return report_text
