# syscall constants
PRINT_STRING = 4
PRINT_CHAR   = 11
PRINT_INT    = 1

# debug constants
PRINT_INT_ADDR   = 0xffff0080
PRINT_FLOAT_ADDR = 0xffff0084
PRINT_HEX_ADDR   = 0xffff0088

# spimbot constants
VELOCITY       = 0xffff0010
ANGLE          = 0xffff0014
ANGLE_CONTROL  = 0xffff0018
BOT_X          = 0xffff0020
BOT_Y          = 0xffff0024
OTHER_BOT_X    = 0xffff00a0
OTHER_BOT_Y    = 0xffff00a4
TIMER          = 0xffff001c
SCORES_REQUEST = 0xffff1018

PLANT_SCAN            = 0xffff0050
CLOUD_SCAN            = 0xffff0054
CLOUD_STATUS_INFO     = 0xffff00c0
GET_WATER             = 0xffff00c8
WATER_VALVE           = 0xffff00c4
REQUEST_PUZZLE        = 0xffff00d0
REQUEST_PUZZLE_STRING = 0xffff00dc
SUBMIT_SOLUTION       = 0xffff00d4

# interrupts constants
BONK_MASK  = 0x1000
BONK_ACK   = 0xffff0060
TIMER_MASK = 0x8000
TIMER_ACK  = 0xffff006c

CLOUD_CHANGE_STATUS_ACK      = 0xffff0064
CLOUD_CHANGE_STATUS_INT_MASK = 0x2000
OUT_OF_WATER_ACK             = 0xffff0068
OUT_OF_WATER_INT_MASK        = 0x4000
PLANT_FULLY_WATERED_ACK      = 0xffff0058
PLANT_FULLY_WATERED_INT_MASK = 0x400
REQUEST_PUZZLE_ACK           = 0xffff00d8
REQUEST_PUZZLE_INT_MASK      = 0x800

.data
# data things go here
.align 2
cloud_data:	.space 40
.align 2
plant_data:	.space 88

.text
water_plant:
	# go wild
	# the world is your oyster :)
	
	sub	$sp, $sp, 32
	sw	$ra, 0($sp)
	sw	$s0, 4($sp)
	sw	$s1, 8($sp)
	sw	$s2, 12($sp)
	sw	$s3, 16($sp)
	sw	$s4, 20($sp)
	#sw	$s5, 24($sp)
	#sw	$s6, 28($sp)
	#sw	$s7, 32($sp)

	lw	$s0, BOT_X				#s0 contains current bot.x

	lw	$s1, GET_WATER				#s1 contains how much water we have

	bne	$s1, $0, water_a_plant			#if we're out of water request some
	jal	request_water				#eg solve a puzzle

water_a_plant:
	la	$s2, plant_data
	sw	$s2, plant_SCAN

get_plant_x:
	move	$s3, $a0				#s3 = plant1.x
	
move_to_plant:
	bgt	$s0, $s3, move_left			#move left if bot.x > plant.x
	blt	$s0, $s3, move_right			#move right if bot.x < plant.x
	j	open_valve				#otherwise we're over the plant already

move_left:
	li	$s4, 180				#prep to face bot left
	j	movement_io

move_right:
	li	$s4, 0					#prep to face bot right
	j	movement_io

movement_io:
	sw	$s4, ANGLE				#set bot angle based on earlier li
	li	$s4, 1					#use absolute angle
	sw	$s4, ANGLE_CONTROL
	li	$s4, 10					#bot velocity = 10
	sw	$s4, VELOCITY				#bot is now moving towards plant
							
keep_moving:
	lw	$s4, BOT_X				#update bot's current X pos
	beq	$s4, $s3, open_valve			#stop if we're above the plant
	j	keep_moving				#otherwise keep moving

open_valve:
	li	$s4, 1					#store this to open water valve
	sw	$s4, WATER_VALVE			#open the water valve
	j	release_water				#enter plant-watering subloop

release_water:
	lw	$s1, GET_WATER				#get current water amount
	bne	$s1, $0, not_out_of_water		#if we're out of water
	jal	request_water				#request more

not_out_of_water:					#otherwise
	lw	$s4, 4($s2)				#poll for the first plant's x pos
	beq	$s0, $s3, release_water			#check that the first plant is still beneath us
							#if not, we've finished watering the plant
	j	close_valve				#so close the valve and exit the function

close_valve:
	li	$s4, 0					#store this to close the valve
	sw	$s4, WATER_VALVE			#close the valve
	j	end_func				#exit the function

end_func:
	add	$sp, $sp, 32
	lw	$ra, 0($sp)
	lw	$s0, 4($sp)
	lw	$s1, 8($sp)
	lw	$s2, 12($sp)
	lw	$s3, 16($sp)
	lw	$s4, 20($sp)
	#lw	$s5, 24($sp)
	#lw	$s6, 28($sp)
	#lw	$s7, 32($sp)
	jr	$ra
