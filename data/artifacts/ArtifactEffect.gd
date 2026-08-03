class_name ArtifactEffect
extends RefCounted
## Legacy executor kept for compatibility. Remake uses ArtifactBehavior via ArtifactManager.

var artifact_data: ArtifactsData
var target_unit: Node
var context: Dictionary

func _init(artifact: ArtifactsData, target: Node = null, ctx: Dictionary = {}):
	artifact_data = artifact
	target_unit = target
	context = ctx

func execute() -> bool:
	# Behaviors own logic now.
	return false
