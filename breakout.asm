################ CSC258H1F Fall 2022 Assembly Final Project ##################
# This file contains our implementation of Breakout.
#
# Student 1: Sirui Chen, 1006740671
# Student 2: Tianyi Pan, 1007643739
######################## Bitmap Display Configuration ########################
# - Unit width in pixels:       8
# - Unit height in pixels:      8
# - Display width in pixels:    512
# - Display height in pixels:   256
# - Base Address for Display:   0x10008000 ($gp)
##############################################################################

    .data
##############################################################################
# Immutable Data
##############################################################################
# The address of the bitmap display. Don't forget to connect it!
ADDR_DSPL:
    .word 0x10008000
# The address of the keyboard. Don't forget to connect it!
ADDR_KBRD:
    .word 0xffff0000
   
ROW_WALL: .word 64
COLUMN_WALL: .word 30
ROW_BRICKS: .word 15 # brick_size = 4, each row has 15 bricks
NUM_ROWS: 6

WALL_COLOR: .word 0x808080 # grey
BALL_COLOR: .word 0xffffff # white
PADDLE_COLOR: .word 0x55aaff # light blue
BRICKS_COLOR: 
	.word 0xff0000 # red
	.word 0xffa500 # orange
	.word 0xffff00 # yellow
	.word 0x008080 # teal
	.word 0x823ba0 # purple
	.word 0xe080a0 # pink

##############################################################################
# Mutable Data
##############################################################################
ball: .word 0x10009c80
paddle: .word 0x10009d80
bricks_visibility: .word 1:90 # 6 rows * 15 bricks each row; 1 = brick visible, 0 otherwise
##############################################################################
# Code
##############################################################################
	.text
	.globl main

.macro sleep (%time) # in milli-seconds
	li	$v0, 32
	li	$a0, %time
	syscall
.end_macro

	# Run the Brick Breaker game.
main:
    # Initialize the game
draw_background:
	load_save_register:
		lw $s0, ADDR_DSPL
		lw $s1, ball
		lw $s2, paddle
		li $s3, 0 # horizontal direction, one of [-4, 0, 4]
		li $s4, 0 # vertical direction, one of [-256, 0, 256]
		li $s5, 0 # start enable

	draw_top_wall:
		addi $t1, $zero, 0 # i
		lw $t2, ROW_WALL # iteration number
		lw $t3, WALL_COLOR # wall color
		lw $t4, ADDR_DSPL # wall bit address
		for_draw_top_wall:
			slt $t9, $t1, $t2
			beq $t9, $zero, draw_left_wall
			sw $t3, 0($t4)
			addi $t4, $t4, 4
			addi $t1, $t1, 1
			b for_draw_top_wall
	draw_left_wall:
		addi $t1, $zero, 0 # i
		lw $t2, COLUMN_WALL # iteration number
		lw $t4, ADDR_DSPL # wall bit address
		for_draw_left_wall:
			slt $t9, $t1, $t2
			beq $t9, $zero, draw_right_wall
			sw $t3, 0($t4)
			addi $t4, $t4, 256
			addi $t1, $t1, 1
			b for_draw_left_wall
	draw_right_wall:
		addi $t1, $zero, 0 # i
		lw $t2, COLUMN_WALL # iteration number
		lw $t4, ADDR_DSPL
		addi $t4, $t4, 252 # wall bit address
		for_draw_right_wall:
			slt $t9, $t1, $t2
			beq $t9, $zero, done_draw_wall
			sw $t3, 0($t4)
			addi $t4, $t4, 256
			addi $t1, $t1, 1
			b for_draw_right_wall
	done_draw_wall:
	
	draw_bricks:
		la $a0, BRICKS_COLOR # bricks color address for this row
		la $a1, ADDR_DSPL # wall bit address
		lw $a1, 0($a1)
		# lw $a1, ADDR_DSPL
		addi $a1, $a1, 264 # first brick address of first row 256+4+4
		la $a2, bricks_visibility # visibiity of the first brick in first row
		
		addi $t1, $zero, 0 # ith row gonna draw
		lw $t2, NUM_ROWS # iteration number
		for_draw_lines:
			slt $t9, $t1, $t2
			beq $t9, $zero, done_draw_bricks
			jal draw_line
			addi $t1, $t1, 1 # increament to i+1
			addi $a0, $a0, 4 # color for next row
			addi $a1, $a1, 16 # first brick of next row
			b for_draw_lines
	done_draw_bricks:
	
		nop
	sleep (500)

game_loop:
	# 1a. Check if key has been pressed
	keyboard_check:
		lw $t0, ADDR_KBRD               # $t0 = base address for keyboard
    	lw $t8, 0($t0)                  # Load first word from keyboard
		beq $t8, 1, keyboard_input      # If first word 1, key is pressed
    	b done_respond

    # 1b. Check which key has been pressed
    keyboard_input:
    	lw $a0, 4($t0)                  # Load second word from keyboard
		beq $a0, 0x20, respond_to_blank # start the game
    	beq $a0, 0x71, respond_to_q     # Check if the key q was pressed (quit)
    	beq $a0, 0x72, respond_to_r		 # Check if the key r was pressed (restart)
		beq $a0, 0x61, respond_to_a		# move paddle to the left
		beq $a0, 0x64, respond_to_d		# move paddle to the right

    	b done_respond
		
    	# below are different branch responses for different key inputs
    	respond_to_q:
    		j finish_program
		respond_to_blank:
			li $s4, -256
			li $s5, 1
			b done_respond
		respond_to_r:
			# clear background
			li $t1, 0 # start i
			li $t2, 2048 # 64 rows * 32 columns
			move $t4, $s0
			for_clear_background:
				slt $t9, $t1, $t2
				beqz $t9, done_clear_background
				sw $zero, 0($t4)
				addi $t4, $t4, 4
				addi $t1, $t1, 1
				b for_clear_background
			done_clear_background:
				j main
		respond_to_a:
			beqz $s5, done_respond # if haven't started, cannot move
			li $t0, 0x10009d0c # left most core can reach
			slt $t9, $t0, $s2
			beqz $t9,done_draw_paddle # omit move at the edge
			sw $zero, 8($s2)
			addi $s2, $s2, -4
			b done_respond
		respond_to_d:
			beqz $s5, done_respond # if haven't started, cannot move
			li $t0, 0x10009df0 # right most core can reach
			slt $t9, $s2, $t0
			beqz $t9,done_respond # omit move at the edge
			sw $zero, -8($s2)
			addi $s2, $s2, 4
			b done_respond
	done_respond:
		nop






    # 2a. Check for collisions
	check_collision:
		check_brick_collision:









		check_wall_collision:







		check_paddle_collision:
			slt $t9, $s4, $zero # check paddle collision iff vertical direction is negative
			beq $t9, $zero, done_collision
			# make $t6 its next brick
			add $t6, $s1, $s3 # add horizontal direction
			add $t6, $s1, $s4 # add vertical direction
			# check the line of the next brick
			move $t7, $t6 # store the quotient, i.e. the line number of next brick
			sub $t7, $t7, $s0
			div $t7, 256
			mfhi $t0
			beq $t0, 32, finish_program # if the ball is at the bottom of the bitmap display
			beq $t0, 29, paddle_collision_change
			b done_collision
			paddle_collision_change:
				lw $t3, 0($t6) # color at its next brick
				beqz $t3, done_collision # if color is black, done detection
				# here detect which section of the paddle is hit
				# Precondition: $t6 and $s2 in the same line
				sub $t0, $s2, $t6
				abs $t0, $t0 # here $t0 should be one of [0, 1, 2]
				beq $t0, 2, invert_paddle_ball_direction
				# if collides in the middle, just invert vertical direction
				sub $s4, $zero, $t4
				b done_paddle_collision
				invert_paddle_ball_direction:
					jal invert_direction
			done_paddle_collision:
				nop

	done_collision:
		nop








	# 2b. Update locations for ball
	update_ball:
		sw $zero, 0($s1) # clear original ball
		add $s1, $s1, $s3 # add horizontal direction
		add $s1, $s1, $s4 # add vertical direction
	# 3. Draw the screen
	draw_screen:
		draw_ball:
			lw $t3, BALL_COLOR
			sw $t3, 0($s1)
		draw_paddle:
			lw $t3, PADDLE_COLOR
			li $t1, 0 # start i
			li $t2, 5 # iteration number
			addi $t4, $s2, -8 # start from -2 word from core
			for_draw_paddle:
				slt $t9, $t1, $t2
				beq $t9, $zero, done_draw_paddle
				sw $t3, 0($t4)
				addi $t4, $t4, 4
				addi $t1, $t1, 1
				b for_draw_paddle
			done_draw_paddle:
				nop
	# 4. Sleep
	sleep (500)
    # 5. Go back to 1
    b game_loop

finish_program:
	li $v0, 10
	syscall

##############################################################################
# Functions
##############################################################################
# draw_line(color_address, brick_address, visibility_address)
draw_line:
	addi $t6, $zero, 0 # i
	lw $t7, ROW_BRICKS # iteration number per row
	lw $t3, 0($a0) # store bricks color for this row
	for_draw_line:
		slt $t9, $t6, $t7 # i < iteration num
		beq $t9, $zero, done_draw_line
		lw $t5, 0($a2) # $t5 = visibility[i]
		beqz $t5, next_brick
		sw $t3, 0($a1)
		sw $t3, 4($a1)
		sw $t3, 8($a1)
		sw $t3, 12($a1)
		j next_brick
	# else: addi $a1, $a1, 12
	next_brick:
		addi $a1, $a1, 16
		addi $t6, $t6, 1
		addi $a2, $a2, 4
		b for_draw_line
	done_draw_line: 
		jr $ra

invert_direction:
	sub $s3, $zero, $s3
	sub $s4, $zero, $s4
	jr $ra