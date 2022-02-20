extends KinematicBody2D

const DustEffect = preload("res://Effects/DustEffect.tscn")
const PlayerBullet = preload("res://Player/PlayerBullet.tscn")
const JumpEffect = preload("res://Effects/JumpEffect.tscn")

var PlayerStats = ResourceLoader.PlayerStats

export (int) var ACCELERATION = 512
export (int) var MAX_SPEED = 64
export (float) var FRICTION = .25
export (int) var GRAVITY = 200
export (int) var JUMP_FORCE = 128
export (int) var MAX_SLOPE_ANGLE = 46
export (int) var BULLET_SPEED = 250

var motion = Vector2.ZERO
var snap_vector = Vector2.ZERO
var just_jumped = false
var invincible = false setget is_invincible

onready var sprite = $Sprite
onready var spriteAnimator = $SpriteAnimator
onready var coyoteJumpTimer = $CoyoteJumpTimer
onready var gun = $Sprite/PlayerGun
onready var muzzle = $Sprite/PlayerGun/Sprite/Muzzle
onready var fireBulletTimer = $FireBulletTimer
onready var BlinkAnimator = $BlinkAnimator


func _ready():
	PlayerStats.connect("player_died", self, "_on_died")
	


func is_invincible(value):
	invincible = value


func _physics_process(delta):
	just_jumped = false
	var input_vector = get_input_vector()
	apply_horizontal_force(input_vector, delta)
	apply_friction(input_vector)
	update_vector()
	jump_check()
	apply_gravity(delta)
	update_animations(input_vector)
	move()
	
	if Input.is_action_pressed("fire") and fireBulletTimer.time_left == 0:
		fire_bullet()

func fire_bullet():
	var bullet = Utils.instance_scene_on_main(PlayerBullet, muzzle.global_position)
	bullet.velocity = Vector2.RIGHT.rotated(gun.rotation)*BULLET_SPEED
	bullet.velocity.x *= sprite.scale.x
	bullet.rotation = bullet.velocity.angle()
	fireBulletTimer.start()
 
func create_dust_effect():
	var dust_position = global_position
	dust_position.x += rand_range(-4,4)
	Utils.instance_scene_on_main(DustEffect, dust_position)
	
func get_input_vector(): 
	var input_vector = Vector2.ZERO
	input_vector.x = Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left")
	return input_vector


func apply_horizontal_force(input_vector, delta):
	if input_vector.x != 0:
		motion.x += input_vector.x * ACCELERATION * delta
		motion.x = clamp(motion.x, -MAX_SPEED, MAX_SPEED)

func apply_friction(input_vector):
	if input_vector.x == 0 && is_on_floor():
		motion.x = lerp(input_vector.x, 0 , FRICTION)

# Function to improve slope handling and jumping. Check if on floor;
# if true, snap vector points DOWN to allow jumping		
func update_vector():
	if is_on_floor():
		snap_vector = Vector2.DOWN
		
func jump_check():
	if is_on_floor() or coyoteJumpTimer.time_left > 0:
		if Input.is_action_just_pressed("ui_up"):
			Utils.instance_scene_on_main(JumpEffect, global_position)
			motion.y = -JUMP_FORCE
			just_jumped = true
			snap_vector = Vector2.ZERO


	else:
		if Input.is_action_just_released("ui_up") and motion.y < -JUMP_FORCE/2:
			 motion.y = -JUMP_FORCE/2
			
			
func apply_gravity(delta):
	if not is_on_floor():
		motion.y += GRAVITY *delta
		motion.y = min(motion.y, JUMP_FORCE)
		

func update_animations(input_vector):
	sprite.scale.x = sign(get_local_mouse_position().x)
	if input_vector.x != 0:
		spriteAnimator.play("Run")
		# Flip animation if player is facing one side and moving to the other
		# spriteAnimator.playback_speed = input_vector.x * sprite.scale.x 
	else:
		spriteAnimator.playback_speed = 1
		spriteAnimator.play("Idle")
		
	if not is_on_floor():
		spriteAnimator.play("Jump")
		

func move():
	# All here except for the motion line are hacks to fix a 2 problems
	# 1- where player jumps off ledge automatically. Look at y value in remote
	#    to get an idea of the issue.
	# 2- If player jumps and lands on a slope, player stops and stutters before moving on.
	var was_in_air = not is_on_floor()
	var was_on_floor = is_on_floor()
	var last_motion = motion
	var last_position = position
	motion = move_and_slide_with_snap(motion, snap_vector*4, Vector2.UP, true, 4, deg2rad(MAX_SLOPE_ANGLE))
	# Landing (issue 2)
	if was_in_air and is_on_floor():
		motion.x = last_motion.x
		Utils.instance_scene_on_main(JumpEffect, global_position)
		
	# Just left ground (issue 1)
	if was_on_floor and not is_on_floor() and  not just_jumped:
		motion.y = 0
		position.y = last_position.y
		coyoteJumpTimer.start()


# warning-ignore:unused_argument
func _on_Hurtbox_hit(damage):
	if not invincible:
		PlayerStats.health -= damage
		BlinkAnimator.play("Blink")


func _on_died():
	queue_free()
