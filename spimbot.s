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
REQ_PUZZLE_MASK = 0X800
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
#.align 2
#puzzle_dict: .space 13528
#.align 2
#puzzle_string: .space 129
#.align 2
#solution_data: .space 516


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
	li	$t0, CLOUD_CHANGE_STATUS_INT_MASK			
	or	$t0, $t0, BONK_MASK								# bonk interrupt bit
	or 	$t0, $t0, REQ_PUZZLE_MASK						# request puzzle interrupt bit
	or	$t0, $t0, 1										# global interrupt enable
	mtc0	$t0, $12										# set interrupt mask (Status register)


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


start_puzzle:
	la	$t0, puzzle_dict
	la	$t1, REQUEST_PUZZLE
	sw	$t0, 0(t1)
	jr	$ra




kdata				# interrupt handler data (separated just for readability)
chunkIH:	.space 8	# space for two registers
.align 2
puzzle_dict: .space 13528
.align 2
puzzle_string: .space 129
.align 2
solution_data: .space 516
non_intrpt_str:	.asciiz "Non-interrupt exception\n"
unhandled_str:	.asciiz "Unhandled interrupt type\n"


.ktext 0x80000180
interrupt_handler:
.set noat
	move	$k1, $at		# Save $at                               
.set at
	la	$k0, chunkIH
	sw	$a0, 0($k0)		# Get some free registers                  
	sw	$a1, 4($k0)		# by storing them to a global variable     

	mfc0	$k0, $13		# Get Cause register                       
	srl	$a0, $k0, 2                
	and	$a0, $a0, 0xf		# ExcCode field                            
	bne	$a0, 0, non_intrpt         

interrupt_dispatch:			# Interrupt:
	li		$t9, 10                             
	mfc0	$k0, $13		# Get Cause register, again                 
	beq	$k0, 0, done		# handled all outstanding interrupts     

	and	$a0, $k0, REQ_PUZZLE_MASK    	# is there a request puzzle interrupt?                
	bne	$a0, 0, req_puzzle_interrupt   

	# add dispatch for other interrupt types here.

	li	$v0, PRINT_STRING	# Unhandled interrupt types
	la	$a0, unhandled_str
	syscall 
	j	done


non_intrpt:				# was some non-interrupt
	li	$v0, PRINT_STRING
	la	$a0, non_intrpt_str
	syscall				# print out an error message
	# fall through to done

done:
	la	$k0, chunkIH
	lw	$a0, 0($k0)		# Restore saved registers
	lw	$a1, 4($k0)
.set noat
	move	$at, $k1		# Restore $at
.set at 
	eret


req_puzzle_interrupt:
	sw	$a1, REQ_PUZZLE_ACK 	#Acknowledge interrupt
	j 	solve_puzzle



solve_puzzle:
	sub	$sp, $sp, 32				#push stack pointer
	sw	$ra, 0($sp)
	sw	$s0, 4($sp)
	sw	$s1, 8($sp)
	sw	$s2, 12($sp)
	sw	$s3, 16($sp)
	sw	$s4, 20($sp)
	sw	$s5, 24($sp)
	sw	$s6, 28($sp)
	# Get puzzle
	la  $s0, puzzle_dict			#get the puzzle 
	# Get word to search for
	la  $s1, puzzle_string 			#get the word we intend to search for

	sw 	$s1, REQUEST_PUZZLE_STRING

	la 	$s2, solution_data

	move $a2, $s0
	move $a1, $s1
	move $a0, $s2

	jal split_string

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
	la	$t0, SUBMIT_SOLUTION	
	sw  $s0, 0($t0)  	#store solution into SUBMIT_SOLUTION
	li	$v0, 1			# return 1
	j	ss_return

ss_continue:
	add	$s3, $s3, 1		# ptr++
	j	ss_for

ss_done:
	li	$v0, 0			# return 0

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



