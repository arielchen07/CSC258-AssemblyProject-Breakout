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

SPEED_RATIO: .word 4

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
		li $s6, 0 # speed ratio

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
		# make $t6 its next brick
		add $t6, $s1, $s3 # add horizontal direction
		add $t6, $s1, $s4 # add vertical direction
		move $t7, $t6 # store the quotient, i.e. the line number of next brick
		sub $t7, $t7, $s0
		li $t8, 256 # save divisor
		div $t7, $t8

		check_end_program:
			mfhi $t0
			beq $t0, 32, finish_program # if the ball is at the bottom of the bitmap display
		
		check_wall_collision:
			mfhi $t0
			bne $t0, 0, check_vertical_wall # check top wall
			sub $s4, $zero, $s4 # change vertical direction
			check_vertical_wall:
			mflo $t0
			# if the next brick is the left or the right wall (0 or 63 for remainder), update horizontal direction
			beq $t0, 0, wall_direction_change
			beq $t0, 63, wall_direction_change
			b check_brick_collision
			wall_direction_change:
				sub $s3, $zero, $s3

		check_brick_collision:













		check_paddle_collision:
			slt $t9, $s4, $zero # check paddle collision iff vertical direction is negative
			beq $t9, $zero, done_paddle_collision

			beq $t0, 29, paddle_bottom_check # the line where paddle locates
			b done_paddle_collision

			paddle_bottom_check: # check if the pixel below the ball is paddle
				add $t6, $s1, $s4
				lw $t3, 0($t6) # color at its next brick
				beqz $t3, done_paddle_collision # if color is black, done detection

			paddle_collision_change:
				sub $t0, $s2, $t6
				abs $t5, $t0 # here $t5 should be one of [0, 1, 2]
				# if collides in the middle, just invert vertical direction
				blt $t5, 2, collide_paddle_middle
				# else collide on the edge; break into cases
				beq $t5, -2, collide_paddle_left
				beq $t5, 2, collide_paddle_right

				collide_paddle_middle: # just inv
					sub $s4, $zero, $s4
					b done_collision
				collide_paddle_left:
					# change vertical
					sub $s4, $zero, $s4
					# change horizontal
					addi $s3, $s3, -1
					bne $s3, -2, done_paddle_collision
					li $s3, -1 # make it restricted to direction bound again

				collide_paddle_right:
					# change vertical
					sub $s4, $zero, $s4
					# change horizontal
					addi $s3, $s3, 1
					bne $s3, 2, done_paddle_collision
					li $s3, 1 # make it restricted to direction bound again

		done_paddle_collision:
			nop

	done_collision:
		nop








	# 2b. Update locations for ball
	update_ball:
		addi $s6, $s6, 1
		lw $t4, SPEED_RATIO # ratio of speed
		blt $s6, $t4, draw_screen
		sw $zero, 0($s1) # clear original ball
		add $s1, $s1, $s3 # add horizontal direction
		add $s1, $s1, $s4 # add vertical direction
		move $s6, $zero # reset back to 0, wait for next accumulation
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
	sleep (125)
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