extends KinematicBody2D

export (int)  var MAX_SPEED = 15
var motion = Vector2.ZERO

onready var enemyStats = $EnemyStats

func _on_Hurtbox_hit(damage):
	enemyStats.health -= damage

func _on_EnemyStats_enemy_died():
	queue_free()
