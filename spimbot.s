# current progress and possible solutions:
# we can water plants pretty well if we have sufficient water. 
# a working nearestPlant method would be great
# when we run out of water we suck
# it looks like our puzzle solver isn't returning the right thing 
# (or isn't returning to the right address or something)
# you can put a breakpoint at the acknowledge line of the 
# interrupt handler to step through the logic of the puzzle
# solving process.

# if all else fails, we can try to get this method working
# which should get 10 plants watered no problem
# enter the cloud from the bottom and move it to the first plant
# while this is happening you fill up your water tank
# if your tank is full, go water plants until it's empty. then
# go move clouds again until the tank is full.
# hopefully we can use zohair's code to ensure that 
# we can get into a cloud from any position to pass the test
# cases for 10 clouds.
# this method isn't great against other bots but it can get
# us 60%


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
REQ_PUZZLE_MASK = 0x800
REQ_PUZZLE_ACK = 0xffff00d8

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
.align 2
puzzle_dict: 	.space 13528
.align 2
puzzle_string: 	.space 129
.align 2
solution_data: 	.space 516
new_str_address: .word str_memory
# Don't put anything below this just in case they malloc more than 4096
str_memory: .space 4096

.text
.globl main
main:
	sub	$sp, $sp, 32
	sw	$ra, 0($sp)
	sw	$s0, 4($sp)
	sw	$s1, 8($sp)
	sw	$s2, 12($sp)
	sw	$s3, 16($sp)
	sw	$s4, 20($sp)
	sw	$s5, 24($sp)
	sw	$s6, 28($sp)
	sw	$s7, 32($sp)


	la	$s7, plant_data
	sw	$s7, PLANT_SCAN
	
	lw	$s6, 0($s7)				# s6 = numplants

	li	$s3, 0					# counter for which plant we're on

	li	$t0, REQUEST_PUZZLE_INT_MASK		# enable puzzle interrupts
	or 	$t0, $t0, BONK_MASK
	or	$t0, $t0, CLOUD_CHANGE_STATUS_INT_MASK
	or	$t0, $t0, 1				# global interrupt enable
	mtc0	$t0, $12				# set interrupt mask. what does that mean?

							# still need to load puzzle data
set_y_position:
	li	$s0, 75				# store the desired y value
	lw	$s1, BOT_Y				# get the bot's y location
	bgt	$s1, $s0, move_up			# move up if the bot is too low
	blt	$s1, $s0, move_down			# move down if the bot is too high
	j	destroy_other_spimbots			# otherwise start watering plants

move_up:
	li	$s2, 270				# prep to face the bot up
	j	c_movement_io

move_down:
	li	$s2, 90					# prep to face the bot down
	j	c_movement_io

c_movement_io:
	sw	$s2, ANGLE				# set bot angle based on earlier li
	li	$s2, 1					# use absolute angle
	sw	$s2, ANGLE_CONTROL
	li	$s2, 10					# bot velocity = 10
	sw	$s2, VELOCITY				# bot is now moving towards plant

c_keep_moving:
	lw	$s1, BOT_Y				# update bot's current Y pos
	beq	$s0, $s1, destroy_other_spimbots	# stop if we're at the desired Y pos
	j	c_keep_moving				# otherwise keep moving
	
destroy_other_spimbots:
	#comment the first two insts out if FNP isn't working
	#jal	find_nearest_plant			# returns address of nearest plant
	#move	$a0, $v0				# moves into a0 for next function call
	move	$a0, $s3				# load current plant index into a0
	jal	find_plant
	move	$a0, $v0
	jal	water_plant				# waters the plant in a0
	add	$s3, $s3, 1
	bgt	$s3, $s6, set_s3_0			# if we're at an out-of-index plant, reset to 0
	j	destroy_other_spimbots

set_s3_0:
	li	$s3, 0					# plant index is 0 again
	j	destroy_other_spimbots

c_end:
	sw	$ra, 0($sp)
	sw	$s0, 4($sp)
	sw	$s1, 8($sp)
	sw	$s2, 12($sp)
	sw	$s3, 16($sp)
	sw	$s4, 20($sp)
	sw	$s5, 24($sp)
	sw	$s6, 28($sp)
	sw	$s7, 32($sp)
	add	$sp, $sp, 32
	j	$ra
	

# end of contoller. interrupt handler at the bottom

.globl find_plant
find_plant:
	sub	$sp, $sp, 36
	sw	$ra, 0($sp)
	sw	$s0, 4($sp)
	sw	$s1, 8($sp)
	sw	$s2, 12($sp)
	sw	$s3, 16($sp)
	sw	$s4, 20($sp)
	sw	$s5, 24($sp)
	sw	$s6, 28($sp)
	sw	$s7, 32($sp)

	la	$s7, plant_data
	sw	$s7, PLANT_SCAN

	mul	$s1, $a0, 8				# get offset and put it in $s1
	add	$s1, $s1, 4				# address + offset
	add	$s1, $s1, $s7
	move	$v0, $s1
	j	end_find_plant

end_find_plant:
	lw	$ra, 0($sp)
	lw	$s0, 4($sp)
	lw	$s1, 8($sp)
	lw	$s2, 12($sp)
	lw	$s3, 16($sp)
	lw	$s4, 20($sp)
	lw	$s5, 24($sp)
	lw	$s6, 28($sp)
	lw	$s7, 32($sp)
	add	$sp, $sp, 36
	jr	$ra

# this handles watering a plant. 
# it gets water if needed, and relies on request_water solving a puzzle correctly
.globl water_plant
water_plant:
	sub	$sp, $sp, 28
	sw	$ra, 0($sp)
	sw	$s0, 4($sp)
	sw	$s1, 8($sp)
	sw	$s2, 12($sp)
	sw	$s3, 16($sp)
	sw	$s4, 20($sp)
	#sw	$s5, 24($sp)
	#sw	$s6, 28($sp)
	sw	$s7, 24($sp)

	lw	$s0, BOT_X				# s0 contains current bot.x

	la	$s7, plant_data
	sw	$s7, PLANT_SCAN

	lw	$s1, GET_WATER				# s1 contains how much water we have

	bne	$s1, $0, water_a_plant			# if we're out of water request some
	j	request_water				# eg solve a puzzle
	lw	$s0, BOT_X				# update bot.x

water_a_plant:
	la	$s2, plant_data
	sw	$s2, PLANT_SCAN

get_plant_x:
	#move	$s3, $a0				# s3 = nearestPlant.x
	lw	$s3, 0($a0)	#if FNP isn't working

move_to_plant:
	bgt	$s0, $s3, move_left			# move left if bot.x > plant.x
	blt	$s0, $s3, move_right			# move right if bot.x < plant.x
	j	open_valve				# otherwise we're over the plant already

move_left:
	li	$s4, 180				# prep to face bot left
	j	wp_movement_io

move_right:
	li	$s4, 0					# prep to face bot right
	j	wp_movement_io

wp_movement_io:
	sw	$s4, ANGLE				# set bot angle based on earlier li
	li	$s4, 1					# use absolute angle
	sw	$s4, ANGLE_CONTROL			# bot is now moving towards plant
	li	$s4, 10
	sw	$s4, VELOCITY
							
keep_moving_sideways:
	lw	$s0, BOT_X				# update bot's current X pos
	beq	$s0, $s3, open_valve			# stop if we're above the plant
	j	keep_moving_sideways			# otherwise keep moving

open_valve:
	li	$s4, 0					# stop the bot from moving
	sw	$s4, VELOCITY
	li	$s4, 1					# store this to open water valve
	sw	$s4, WATER_VALVE			# open the water valve
	j	release_water_improved			# enter plant-watering subloop

release_water_improved:
	lw	$s1, GET_WATER				# get current water amount
	sub 	$s5, $s1, 4				# s5 = 4 drops less than we have
	j	drop_4_drops

drop_4_drops:
	lw	$s1, GET_WATER
	ble	$s1, $s5, close_valve			# if the plant is watered we're done
	bne	$s1, $0, dont_req_water
	jal	request_water

dont_req_water:						# if we're out of water get more
	j	drop_4_drops

#release_water:
#	lw	$s1, GET_WATER				# get current water amount
#	bne	$s1, $0, not_out_of_water		# if we're out of water
#	j	request_water				# request more

#not_out_of_water:					# otherwise
#	la	$s2, plant_data				# update plant_data
#	sw	$s2, PLANT_SCAN				# with the scanned plant values
#	#move	$s3, $a0				# poll for the "nearest" plant's x pos
#	lw	$s3, 4($s7) 	#if FNP isn't working
#	beq	$s0, $s3, release_water			# check that the "nearest" plant is still beneath us
#							# if not, we've finished watering the plant
#	j	close_valve				# so close the valve and exit the function

close_valve:
	li	$s4, 0					# store this to close the valve
	sw	$s4, WATER_VALVE			# close the valve
	j	end_func				# exit the function

end_func:
	lw	$ra, 0($sp)
	lw	$s0, 4($sp)
	lw	$s1, 8($sp)
	lw	$s2, 12($sp)
	lw	$s3, 16($sp)
	lw	$s4, 20($sp)
	#lw	$s5, 24($sp)
	#lw	$s6, 28($sp)
	lw	$s7, 24($sp)
	add	$sp, $sp, 28
	jr	$ra

.globl request_water
request_water:
	la	$t0, puzzle_dict
	sw	$t0, REQUEST_PUZZLE

wait_for_solved_puzzle:
	lw	$t0, GET_WATER
	bgt	$t0, 2, return
	j	wait_for_solved_puzzle

return:
	jr	$ra





.globl find_nearest_plant
find_nearest_plant:
	sub	$sp, $sp, 32				# creating 8-word stackframe
	sw 	$ra, 0($sp)				# exit the function
	sw 	$s0, 4($sp)				# plant_data array address
	sw 	$s1, 8($sp)				# Bot_X location
	sw 	$s2, 12($sp)				# current plant x location
	sw 	$s3, 16($sp)				# closest plant x location
	sw 	$s4, 20($sp)				# end condition - maximum value of $s0
	sw 	$s5, 24($sp) 				# temp distance register
	sw 	$s6, 28($sp) 				# temp distance register

	la 	$s0, plant_data
	sw 	$s0, PLANT_SCAN				# handled in controller code

	lw 	$s1, 0($s0)				# num_plants
	mul  	$s4, $s1, 8
	add 	$s4, $s4, 4 				# maximum value of $s0

	add 	$s0, $s0, 4				# bring s0 to first plant

	li 	$s3, 0x0FFFFFFF				# initialize $s3 to a big value

# loop pseudocode
# for(plant p : plants) {
# 	if(abs(bot.x - p.x) < abs(bot.x - minplant.x)) {
# 		minplant = p;		// store address in $v0
# 	}
# }

fnp_loop:
	bge 	$s0, $s4, fnp_return			# loop end condition
	lw 	$s1, BOT_X
	lw 	$s2, 0($s0)				# get current plant x


	sub 	$a0, $s1, $s2

	jal 	absolute_val
	move 	$s5, $v0				# $s5 = abs($s1 - $s2)


	sub 	$a0, $s1, $s3

	jal 	absolute_val
	move 	$s6, $v0				# $s6 = abs($s1 - $s3)

	bge 	$s5, $s6, fnp_loop_skip

	move 	$v0, $s0				# return value = address of current lowest plant
	move 	$s3, $s2				# nearest plant x = current plant x

fnp_loop_skip:
	add 	$s0, $s0, 8				# go to next plant
	j 	fnp_loop

fnp_return:
	lw 	$ra, 0($sp)
	lw 	$s0, 4($sp)
	lw 	$s1, 8($sp)
	lw 	$s2, 12($sp)
	lw 	$s3, 16($sp)
	lw 	$s4, 20($sp)
	lw 	$s5, 24($sp)
	lw 	$s6, 28($sp)
	add 	$sp, $sp, 32				# destroy stackfame

	jr	$ra					# jump to $ra

.globl absolute_val
absolute_val:
	sub 	$sp, $sp, 4	
	sw 	$s0, 0($sp)				# boolean for if $a0 < 0

	slt 	$s0, $a0, $zero      			# is value < 0 ?
  	beq 	$s0, $zero, abs_return  		# if $a0 is positive, skip next inst
    	sub 	$v0, $zero, $a0    			# $v0 = 0 - $a0

abs_return:
	lw 	$s0, 0($sp)
	add 	$sp, $sp, 4				# destroy stackfame
	jr	$ra					# jump to $ra


.kdata							# interrupt handler data (separated just for readability)
chunkIH:	.space 8				# space for two registers
#.align 2
#puzzle_dict: 	.space 13528
#.align 2
#puzzle_string:	.space 129
#.align 2
#solution_data: 	.space 516
non_intrpt_str:	.asciiz "Non-interrupt exception\n"
unhandled_str:	.asciiz "Unhandled interrupt type\n"


.ktext 0x80000180
interrupt_handler:
.set noat
	move	$k1, $at					# Save $at                               
.set at
	la	$k0, chunkIH
	sw	$a0, 0($k0)					# Get some free registers                  
	sw	$a1, 4($k0)					# by storing them to a global variable     

	mfc0	$k0, $13					# Get Cause register                       
	srl	$a0, $k0, 2                
	and	$a0, $a0, 0xf					# ExcCode field                            
	bne	$a0, 0, non_intrpt         

interrupt_dispatch:						# Interrupt:
	li	$t9, 10                             
	mfc0	$k0, $13					# Get Cause register, again                 
	beq	$k0, 0, done					# handled all outstanding interrupts     

	and	$a0, $k0, REQ_PUZZLE_MASK    			# is there a request puzzle interrupt?                
	bne	$a0, 0, req_puzzle_interrupt   


	and	$a0, $k0, BONK_MASK				# is there a bonk interrupt?                
	bne	$a0, 0, bonk_interrupt   

	and $a0, $k0, CLOUD_CHANGE_STATUS_INT_MASK		#is there a cloud change status interrupt
	bne $a0, 0, cloud_interrupt

	li	$v0, PRINT_STRING				# Unhandled interrupt types
	la	$a0, unhandled_str 
	j	done


non_intrpt:							# was some non-interrupt
	li	$v0, PRINT_STRING
	la	$a0, non_intrpt_str				# print out an error message
	# fall through to done

done:
	la	$k0, chunkIH
	lw	$a0, 0($k0)					# Restore saved registers
	lw	$a1, 4($k0)
.set noat
	move	$at, $k1					# Restore $at
.set at 
	eret


bonk_interrupt:
	sw	$a1, BONK_ACK					# acknowledge interrupt
	sw	$zero, VELOCITY					# make velocity zero

	j	interrupt_dispatch				# see if other interrupts are waiting


cloud_interrupt:
	sw	$a1, CLOUD_CHANGE_STATUS_ACK			#acknowledge interrupt
	la	$t0, CLOUD_STATUS_INFO				#Get cloud status info to figure out the reason behind interrupt
	lb	$t1, 0($t0)					#get char action
	beq	$t1, $zero, interrupt_dispatch			#if our action dictactes is to do nothing, just jump to interrupt_dispatch 
	beq	$t1, 1, enter_cloud				#we are entering a cloud
	beq	$t1, 2, exit_cloud				#we are exiting the cloud

	j 	interrupt_dispatch				#see if other interrupts are waiting

enter_cloud:
	la	$t1, plant_data
	sw	$t1, PLANT_SCAN					#plant_data has now been populated with the array of plant information
	lw	$t2, 4($t1)					#get the plant's x_coordinate
	lw	$t3, BOT_X					#get the bot's x_coordinate
	j	exit_cloud					#leave the cloud instead of doing anything with it for now
	j 	comparison

exit_cloud:
	li	$t3, 1
	sw	$t3, ANGLE_CONTROL				#make sure angle is absolute rather than relative	
	li	$t3, 270			
	sw	$t3, ANGLE 					#set angle to 270
	li	$t3, 10
	sw	$t3, VELOCITY 					#make velocity 1
	lw	$t3, BOT_Y
	bge	$t3, 75, exit_cloud
	j 	interrupt_dispatch

comparison:
	lw	$t3, BOT_X					#get the bot's x_coordinate
	bgt	$t2, $t3, plant_ahead 				#if the plant's x_coordinate is ahead of the bots x_coordinate, jump to plant_ahead
	blt $t2, $t3, plant_behind				#if the plant's x_coordinate is behind the bots x_coordinate, jump to plant_behind
	beq	$t2, $t3, interrupt_dispatch		

plant_ahead:
	li	$t4, 1
	sw	$t4, ANGLE_CONTROL				#make sure angle is absolute rather than relative	
	sw	$zero, ANGLE 					#set angle to zero										
	sw	$t9, VELOCITY           			#set velocity to 1
	j 	comparison					#go to comparison

plant_behind:
	li	$t4, 1
	li	$t6, 180
	sw	$t4, ANGLE_CONTROL				#make sure angle is absolute rather than relative				
	sw	$t6, ANGLE 					#set angle to 180
	sw	$t9, VELOCITY  					#set velocity to 1
	j 	comparison					#go to comparison

req_puzzle_interrupt:
	sw	$a1, REQ_PUZZLE_ACK 				#Acknowledge interrupt
	j 	solve_puzzle

solve_puzzle:
	sub	$sp, $sp, 32					#push stack pointer
	sw	$ra, 0($sp)
	sw	$s0, 4($sp)
	sw	$s1, 8($sp)
	sw	$s2, 12($sp)
	sw	$s3, 16($sp)
	sw	$s4, 20($sp)
	sw	$s5, 24($sp)
	sw	$s6, 28($sp)
	# Get puzzle
	la  	$a2, puzzle_dict				#get the puzzle 
	# Get word to search for
	la  	$a1, puzzle_string 				#get the word we intend to search for

	sw 	$a1, REQUEST_PUZZLE_STRING

	la 	$a0, solution_data

	jal 	split_string
	
	la	$a0, solution_data
	sw	$a0, SUBMIT_SOLUTION	

	j 	interrupt_dispatch				#see if other interrupts are waiting


.globl split_string
split_string:
	sw	$0, 0($a0)
	lb	$t0, 0($a1)
	bne	$t0, $0, ss_recurse
	li	$v0, 1
	jr	$ra

ss_recurse:
	sub	$sp, $sp, 24
	sw	$ra, 0($sp)
	sw	$s0, 4($sp)		# char **solution
	sw	$s1, 8($sp)		# char *str
	sw	$s2, 12($sp)		# dictionary *dict
	sw	$s3, 16($sp)		# char *ptr
	sw	$s4, 20($sp)		# char *prefix

	move	$s0, $a0
	move	$s1, $a1
	move	$s2, $a2
	move	$s3, $a1

ss_for:
	lb	$t0, 0($s3)	        # *ptr
	beq	$t0, $0, ss_done	# *ptr != 0

	move	$a0, $s1		# str
	add	$a1, $s3, 1		# ptr + 1
	sub	$a1, $a1, $s1		# ptr + 1 - str
	jal	sub_str			# sub_str(str, ptr + 1 - str)
	move	$s4, $v0		# prefix

	move	$a0, $s4		# prefix
	add	$a1, $s2, 4		# dict->words
	lw	$a2, 0($s2)		# dict->size
	jal	in_dict			# in_dict(prefix, dict->words, dict->size)
	beq	$v0, $0, ss_continue

	add	$a0, $s0, 4		# solution + 1
	add	$a1, $s3, 1		# ptr + 1
	move	$a2, $s2		# dict
	jal	split_string		# split_string(solution + 1, ptr + 1, dict)
	beq	$v0, $0, ss_continue

	sw	$s4, 0($s0)		# *solution = prefix
	li	$v0, 1			# return 1
	j	ss_return

ss_continue:
	add	$s3, $s3, 1		# ptr++
	j	ss_for

ss_done:
	li	$v0, 0			# return 0
	#do we need to load the address of solution anywhere?
	#store that in $v1 or something?

ss_return:
	lw	$ra, 0($sp)
	lw	$s0, 4($sp)
	lw	$s1, 8($sp)
	lw	$s2, 12($sp)
	lw	$s3, 16($sp)
	lw	$s4, 20($sp)
	add	$sp, $sp, 24
	jr	$ra


.globl sub_str
sub_str:
	sub	$sp, $sp, 12
	sw	$ra, 0($sp)
	sw	$s0, 4($sp)
	sw	$s1, 8($sp)

	move	$s0, $a0		# str
	move	$s1, $a1		# n

	add	$a0, $s1, 1		# n + 1
	jal	malloc			# malloc(n + 1)
	li	$t0, 0			# len = 0

sub_str_for:
	bge	$t0, $s1, sub_str_ret	# len >= n
	add	$t1, $s0, $t0		# &str[len]
	lb	$t1, 0($t1)		# str[len]
	beq	$t1, 0, sub_str_ret	# str[len] == '\0'

	add	$t2, $v0, $t0		# &newstr[len]
	sb	$t1, 0($t2)		# newstr[len] = str[len]

	add	$t0, $t0, 1		# len++
	j	sub_str_for

sub_str_ret:
	add	$t2, $v0, $t0		# &newstr[len]
	sb	$0, 0($t2)		# newstr[len] = '\0' 

	lw	$ra, 0($sp)
	lw	$s0, 4($sp)
	lw	$s1, 8($sp)
	add	$sp, $sp, 12
	jr	$ra


.globl str_cmp
str_cmp:
	lb	$t0, 0($a0)		# *src
	lb	$t1, 0($a1)		# *tgt
	beq	$t0, $0, sc_done	# *srg != 0
	beq	$t1, $0, sc_done	# *tgt != 0
	bne	$t0, $t1, sc_done	# *src != *tgt
	add	$a0, $a0, 1		# src++
	add	$a1, $a1, 1		# tgt++
	j	str_cmp

sc_done:
	bne	$t0, $t1, sc_true	# *src != *tgt
	move	$v0, $0			# return false
	jr	$ra

sc_true:
	li	$v0, 1			# return true
	jr	$ra

.globl length
length:
	li	$v0, 0			# int num_buts = 0

l_for:
	bleu	$a0, $0, l_done		# binary > 0
	bge	$v0, 32, l_done		# num_bits < UNSIGNED_SIZE
	srl	$a0, $a0, 1		# binary = binary >> 1
	add	$v0, $v0, 1		# num_bits++
	j	l_for

l_done:
	jr	$ra			# return num_bits

.globl in_dict
in_dict:
	sub	$sp, $sp, 20
	sw	$ra, 0($sp)
	sw	$s0, 4($sp)		# char *str
	sw	$s1, 8($sp)		# char **dict
	sw	$s2, 12($sp)		# int dict_size
	sw	$s7, 16($sp)		# int i

	move	$s0, $a0
	move	$s1, $a1
	move	$s2, $a2
	move	$s7, $0			# i = 0

id_for:
	bge	$s7, $s2, id_done 	# i < dict_size
	mul	$t0, $s7, 4
	add	$t0, $t0, $s1		# $t0 = &dict[i]
	move	$a0, $s0		# str
	lw	$a1, 0($t0)		# dict[i]
	jal	str_cmp			# str_cmp(str, dict[i])
	beq	$v0, $0, id_ret_1	# if (!str_cmp(str, dict[i]))
	add	$s7, $s7, 1		# i++
	j	id_for

id_ret_1:
	li	$v0, 1			# return 1
	j	id_ret

id_done:
	move	$v0, $0			# return 0
id_ret:
	lw	$ra, 0($sp)
	lw	$s0, 4($sp)		# char *str
	lw	$s1, 8($sp)		# char **dict
	lw	$s2, 12($sp)		# int dict_size
	lw	$s7, 16($sp)		# int i
	add	$sp, $sp, 20
	jr	$ra

.globl crc_encoding
crc_encoding:
	sub	$sp, $sp, 20
	sw	$ra, 0($sp)
	sw	$s0, 4($sp)		# unsigned dividend
	sw	$s1, 8($sp)		# unsigned divisor
	sw	$s2, 12($sp)		# int divisor_length
	sw	$s3, 16($sp)		# unsigned remainder

	move	$s0, $a0
	move	$s1, $a1

	move	$a0, $a1
	jal	length			# length(divisor)
	move	$s2, $v0		# divisor_length = length(divisor)

	sub	$t0, $s2, 1		# divisor_length - 1
	sll	$s3, $s0, $t0		# remainder = dividend << (divisor_length -1)
	move	$a0, $s3
	jal	length			# length(remainder)
	move	$t0, $v0		# remainder_length = length(remainder) (which is also i)

ce_for:
	blt	$t0, $s2, ce_done
	sub	$t9, $t0, 1
	srl	$t9, $s3, $t9		# unsigned msb = remainder >> (i - i)

	beq	$t9, $0, ce_cont 	# if (msb)
	sub	$t5, $t0, $s2		# i - divisor_length
	sll	$t5, $s1, $t5		# divisor (i - divisor_length	)
	xor	$s3, $s3, $t5		# remainder ^ (divisor (i - divisor_length))

ce_cont:
	sub	$t0, $t0, 1		# i--
	j	ce_for

ce_done:
	sub	$v0, $s2, 1		# divisor_length - 1
	sll	$v0, $s0, $v0		# dividend << (divisor_length - 1)
	xor	$v0, $v0, $s3		# (dividend << (divisor_length - 1)) ^ remainder

	lw	$ra, 0($sp)
	lw	$s0, 4($sp)		# unsigned dividend
	lw	$s1, 8($sp)		# unsigned divisor
	lw	$s2, 12($sp)		# int divisor_length
	lw	$s3, 16($sp)		# unsigned remainder
	add	$sp, $sp, 20
	jr	$ra

.globl malloc
malloc:
	lw	$v0, new_str_address
	add	$t0, $v0, $a0
	sw	$t0, new_str_address
	jr	$ra
