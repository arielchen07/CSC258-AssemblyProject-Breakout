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
NUM_ROWS: .word 6

WALL_COLOR: .word 0x808080 # grey
BALL_COLOR: .word 0xffffff # white
PADDLE_COLOR: .word 0x55aaff # light blue
BRICKS_COLOR: 
	.word 0xff0000 # red
	.word 0xffa500 # orange
	.word 0xffff00 # yellow
	.word 0xdef2e1 # teal
	.word 0x823ba0 # purple
	.word 0xe080a0 # pink

SPEED_RATIO: .word 4

NUMBER_DISPLAY_LEFT: .word 0x10008e10
NUMBER_DISPLAY_RIGHT: .word 0x10008ed0
NUMBER_DISPLAY_CENTER: .word 0x10008e74

##############################################################################
# Mutable Data
##############################################################################
ball: .word 0x10009c80
paddle: .word 0x10009d80
bricks_visibility: .word 0:90 # 6 rows * 15 bricks each row; 1 = brick visible, 0 otherwise

edit_enable: .word 0 # edit enable for number display

highest_score: .word 0
current_score: .word 0

pause_enable: .word 0 # 0 if not pause, 1 if pause

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
		li $s6, 0 # speed ratio counter

		# set pause_enable to 0
		la $t0, pause_enable
		sw $zero, 0($t0)
		# set current_score to 0
		la $t0, current_score
		sw $zero, 0($t0)

	set_brick_visibility:
		li $t1, 0 # i = 0
		li, $t2, 90 # iteration number
		li, $t3, 3 # visibility
		la, $t4, bricks_visibility # address of bricks_visibility
		for_set_visibility:
			slt $t9, $t1, $t2
			beq $t9, $zero, draw_top_wall
			sw $t3, 0($t4)
			addi $t4, $t4, 4
			addi $t1, $t1, 1
			b for_set_visibility

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
		nop

	draw_bricks_init:
		la $a0, BRICKS_COLOR # bricks color address for this row
		la $a1, ADDR_DSPL # wall bit address
		lw $a1, 0($a1)
		# lw $a1, ADDR_DSPL
		addi $a1, $a1, 264 # first brick address of first row 256+4+4
		la $a2, bricks_visibility # visibility of the first brick in first row
		
		addi $t1, $zero, 0 # ith row gonna draw
		lw $t2, NUM_ROWS # iteration number
		for_draw_lines_init:
			slt $t9, $t1, $t2
			beq $t9, $zero, done_draw_bricks_init
			jal draw_line
			addi $t1, $t1, 1 # increament to i+1
			addi $a0, $a0, 4 # color for next row
			addi $a1, $a1, 16 # first brick of next row
			b for_draw_lines_init
	done_draw_bricks_init:
		nop
	
	# display the highest score at the center
	lw $a0, NUMBER_DISPLAY_CENTER
	lw $a1, highest_score
	jal display_score_number

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
    	beq $a0, 0x72, respond_to_r		# Check if the key r was pressed (restart)
		beq $a0, 0x61, respond_to_a		# move paddle to the left
		beq $a0, 0x64, respond_to_d		# move paddle to the right
		beq $a0, 0x70, respond_to_p		# pause the game

    	b done_respond
		
    	# below are different branch responses for different key inputs
    	respond_to_q:
    		j finish_program
		respond_to_blank:
			# if game already started, ignore blank key press
			bne $s5, $zero, done_respond
			lw $t0, pause_enable
			bne $t0, $zero, done_respond

			# initialize direction
			li $s4, -256
			# activate start enable
			li $s5, 1
			# clear highest score in the middle
			lw $a0, NUMBER_DISPLAY_CENTER
			jal remove_number
			# display current score (0) on the right
			lw $a0, NUMBER_DISPLAY_RIGHT
			move $a1, $zero
			jal display_score_number
			# start the game
			b done_respond
		respond_to_r:
			# clear background
			jal clear_screen
			# go back and restart
			j main
		respond_to_a:
			beqz $s5, done_respond # if haven't started, cannot move
			lw $t0, pause_enable
			bne $t0, $zero, done_respond

			li $t0, 0x10009d0c # left most core can reach
			slt $t9, $t0, $s2
			beqz $t9,done_draw_paddle # omit move at the edge
			sw $zero, 8($s2)
			addi $s2, $s2, -4
			b done_respond
		respond_to_d:
			beqz $s5, done_respond # if haven't started, cannot move
			lw $t0, pause_enable
			bne $t0, $zero, done_respond

			li $t0, 0x10009df0 # right most core can reach
			slt $t9, $s2, $t0
			beqz $t9,done_respond # omit move at the edge
			sw $zero, -8($s2)
			addi $s2, $s2, 4
			b done_respond
		respond_to_p:
			beqz $s5, done_respond
			la $t1, pause_enable
			lw $t0, 0($t1)
			bne $t0, $zero, continue # if not pause yet, pause
			# change pause_enable
			li $t3, 1
			sw $t3, 0($t1)
			# save current direction
			addi $sp, $sp, -4
			sw $s3, 0($sp)
			addi $sp, $sp, -4
			sw $s4, 0($sp)
			b done_respond

			continue:
				# change pause_enable
				sw $zero, 0($t1)
				# load direction back
				lw $s4, 0($sp)
				addi $sp, $sp, 4
				lw $s3, 0($sp)
				addi $sp, $sp, 4
				b done_respond

	done_respond:
		nop
	


	# check if all bricks has been broken
	lw $t0, current_score
	li $t1, 90
	slt $t9, $t0, $t1
	# if $t0 >= 90, jump to the end of the game
	beqz $t9, end_of_game

    # 2a. Check for collisions
	# only check if ball is about to move
	beqz $s5, done_collision
	lw $t0, pause_enable
	bne $t0, $zero, sleep_in_game
	
	lw $t4, SPEED_RATIO
	addi $t4, $t4, -1
	slt $t9, $s6, $t4
	beq $t9, 1, done_collision
	check_collision:
		# make $t6 its next brick
		add $t6, $s1, $s3 # add horizontal direction
		add $t6, $t6, $s4 # add vertical direction
		move $t7, $t6 # store the quotient, i.e. the line number of next brick
		sub $t7, $t7, $s0
		li $t8, 256 # save divisor
		div $t7, $t8

		check_end_program:
			mflo $t0 # quotient
			beq $t0, 32, end_of_game # if the ball is at the bottom of the bitmap display
			bgt $t0, 30, done_collision
		
		check_wall_collision:
			mflo $t0 # row number
			bne $t0, 0, check_vertical_wall # check top wall
			sub $s4, $zero, $s4 # change vertical direction (collide with top wall)
			check_vertical_wall:
			mfhi $t0 # column number
			# if the next brick is the left or the right wall (0 or 63 for remainder), update horizontal direction
			beq $t0, 0, wall_direction_change
			beq $t0, 252, wall_direction_change
			b check_brick_collision
			wall_direction_change:
				sub $s3, $zero, $s3 # horizontal direction change

		check_brick_collision:
			# make $t6 its next brick
			add $t6, $s1, $s3 # add horizontal direction
			add $t6, $t6, $s4 # add vertical direction
			move $t7, $t6 # store the quotient, i.e. the line number of next brick
			sub $t7, $t7, $s0
			li $t8, 256 # save divisor
			div $t7, $t8
			mflo $t0 # row number
			bgt $t0, 10, done_brick_collision

			# check for top brick
			# corner_enable: which is nonzero after vertical and side check
			# if and only if one of the bricks is removed
			li $s7, 0 # corner enable
			collide_vertical_brick:
				beqz $s4, collide_side_brick
				add $t6, $s1, $s4
				lw $t3, 0($t6) # color of the vertical brick in its direction
				sne $s7, $t3, $zero
				# check if collision occurs
				beqz $t3, collide_side_brick
				move $a0, $t6
				jal reduce_visibility
				# change edit enable
				la $t0, edit_enable
				lw $t9, 0($t0)
				addi $t9, $t9, 1 # enable edit
				sw $t9, 0($t0)
				# change current score
				la $t0, current_score
				lw $t1, 0($t0)
				add $t1, $t1, $v0
				sw $t1, 0($t0)
				# change vertical direction
				sub $s4, $zero, $s4
			# check for side brick
			collide_side_brick:
				beqz $s3, collide_corner_brick
				add $t6, $s1, $s3
				lw $t3, 0($t6)
				sne $s7, $t3, $zero
				# check if collision occurs
				beqz $t3, collide_corner_brick
				move $a0, $t6
				jal reduce_visibility
				# change edit enable
				la $t0, edit_enable
				lw $t9, 0($t0)
				addi $t9, $t9, 1 # enable edit
				sw $t9, 0($t0)
				# change current score
				la $t0, current_score
				lw $t1, 0($t0)
				add $t1, $t1, $v0
				sw $t1, 0($t0)
				# change horizontal direction
				sub $s3, $zero, $s3
			
			# check for corner brick
			collide_corner_brick:
				# if the any of top or side brick exist, done collision
				bne $s7, $zero, done_brick_collision
				# otherwise, move to corner check
				add $t6, $s1, $s3 # add horizontal direction
				add $t6, $t6, $s4 # add vertical direction
				lw $t3, 0($t6)
				beqz $t3, done_brick_collision
				move $a0, $t6
				jal reduce_visibility
				# change edit enable
				la $t0, edit_enable
				lw $t9, 0($t0)
				addi $t9, $t9, 1 # enable edit
				sw $t9, 0($t0)
				# change current score
				la $t0, current_score
				lw $t1, 0($t0)
				add $t1, $t1, $v0
				sw $t1, 0($t0)
				# change both direction
				sub $s3, $zero, $s3
				sub $s4, $zero, $s4
				b done_brick_collision

		done_brick_collision:
			nop



		check_paddle_collision:
			sgt $t9, $s4, $zero # check paddle collision iff vertical direction is downward
			beq $t9, $zero, done_paddle_collision
			
			# make $t6 its next brick
			add $t6, $s1, $s3 # add horizontal direction
			add $t6, $t6, $s4 # add vertical direction
			move $t7, $t6 # store the quotient, i.e. the line number of next brick
			sub $t7, $t7, $s0
			li $t8, 256 # save divisor
			div $t7, $t8
			
			mflo $t0 # quotient
			beq $t0, 29, paddle_bottom_check # the line where paddle locates
			b done_paddle_collision

			paddle_bottom_check: # check if the pixel below the ball is paddle
				add $t6, $s1, $s4
				lw $t3, 0($t6) # color at its next brick
				beqz $t3, collide_paddle_corner # if color is black, done detection

			paddle_collision_change:
				sub $t0, $s2, $t6
				abs $t5, $t0 # here $t5 should be one of [0, 4, 8]
				# if collides in the middle, just invert vertical direction
				blt $t5, 8, collide_paddle_middle
				# else collide on the edge; break into cases
				beq $t0, 8, collide_paddle_left
				beq $t0, -8, collide_paddle_right

				collide_paddle_middle: # just invert vertical direction
					sub $s4, $zero, $s4
					b done_paddle_collision
				collide_paddle_left:
					# change vertical
					sub $s4, $zero, $s4
					# change horizontal
					addi $s3, $s3, -4
					bne $s3, -8, done_paddle_collision
					li $s3, -4 # make it restricted to direction bound again
					b done_paddle_collision

				collide_paddle_right:
					# change vertical
					sub $s4, $zero, $s4
					# change horizontal
					addi $s3, $s3, 4
					bne $s3, 8, done_paddle_collision
					li $s3, 4 # make it restricted to direction bound again
					b done_paddle_collision
				
				collide_paddle_corner:
					# make $t6 the next brick
					add $t6, $s1, $s3 # add horizontal direction
					add $t6, $t6, $s4 # add vertical direction
					# check color of the next brick
					lw $t3, 0($t6)
					beqz $t3, done_paddle_collision # if black, done paddle check
					# else, invert all direction
					sub $s3, $zero, $s3
					sub $s4, $zero, $s4
					b done_paddle_collision

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
		
		lw $t0, edit_enable
		beqz $t0, done_draw_bricks
		draw_bricks:
		la $a0, BRICKS_COLOR # bricks color address for this row
		la $a1, ADDR_DSPL # wall bit address
		lw $a1, 0($a1)
		# lw $a1, ADDR_DSPL
		addi $a1, $a1, 264 # first brick address of first row 256+4+4
		la $a2, bricks_visibility # visibility of the first brick in first row
		
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


		# get current display address
		lw $a0, NUMBER_DISPLAY_LEFT
		lw $t3, 8($a0) # upper-right corner of first digit: must nonzero if already display here
		bne $t3, $zero, done_set_address
		lw $a0, NUMBER_DISPLAY_RIGHT
		done_set_address:
			nop
		
		# check if number display has to change location
		sub $t7, $s1, $s0
		li $t8, 256
		div $t7, $t8
		mfhi $t0 # store the column number
		beq $t0, 192, move_number_left # 48
		beq $t0, 64, move_number_right # 16
		b done_edit_enable
		move_number_left:
			blt $s3, 1, done_edit_enable
			# clear right display
			lw $a0, NUMBER_DISPLAY_RIGHT
			jal remove_number
			# set new display address
			lw $a0, NUMBER_DISPLAY_LEFT

			# activate edit_enable
			la $t0, edit_enable
			lw $t1, 0($t0)
			addi $t1, $t1, 1
			sw $t1, 0($t0)

			b done_edit_enable
		move_number_right:
			bgt $s3, -1, done_edit_enable
			# clear left display
			lw $a0, NUMBER_DISPLAY_LEFT
			jal remove_number
			# set new display address
			lw $a0, NUMBER_DISPLAY_RIGHT

			# activate edit_enable
			la $t0, edit_enable
			lw $t1, 0($t0)
			addi $t1, $t1, 1
			sw $t1, 0($t0)

			b done_edit_enable
		done_edit_enable:
			nop
		
		# update score display
		lw $t0, edit_enable
		beqz $t0, done_update_score
		update_score:
			move $t0, $a0 # temporary store the display address
			jal remove_number
			move $a0, $t0
			lw $a1, current_score
			jal display_score_number
		done_update_score:
			# reset edit enable in game loop
			la $t0, edit_enable
			sw $zero, 0($t0)


	# 4. Sleep
	sleep_in_game:
		sleep (40)
		# 5. Go back to 1
		j game_loop


# the end of game: either out of boundary or hit all bricks
end_of_game:
	# reset the directions
	li $s3, 0
	li $s4, 0
	
	# update and display highest score
	la $t0, highest_score
	lw $t1, 0($t0)
	lw $t2, current_score
	update_highest_score:
		blt $t2, $t1, done_update_highest_score
		# if current_score >= highest_score, set new highest_score
		move $t1, $t2
	done_update_highest_score:
		# save the highest score
		sw $t1, 0($t0)
		# draw highest score on the center
		lw $a0, NUMBER_DISPLAY_CENTER
		move $a1, $t1
		jal display_score_number
		# clear left and right score display
		lw $a0, NUMBER_DISPLAY_LEFT
		jal remove_number
		lw $a0, NUMBER_DISPLAY_RIGHT
		jal remove_number
	j game_loop

finish_program:
	jal clear_screen
	li $v0, 10
	syscall

##############################################################################
# Functions
##############################################################################
# draw_line(color_address, brick_address, visibility_address)
draw_line:
	addi $t6, $zero, 0 # i
	lw $t7, ROW_BRICKS # iteration number per row
	lw $t3, 0($a0) # store (base) bricks color for this row
	for_draw_line:
		slt $t9, $t6, $t7 # i < iteration num
		beq $t9, $zero, done_draw_line
		lw $t5, 0($a2) # $t5 = visibility[i]
		bnez $t5, draw_single_brick
		lw $t4, 0($a1) # current color of brick core
		beqz $t4, next_brick # if it is black, skip to the next brick
		# else, draw to black
		sw $zero, 0($a1)
		sw $zero, 4($a1)
		sw $zero, 8($a1)
		sw $zero, 12($a1)
		b next_brick
		# draw_single_brick iff visibility is nonzero
		draw_single_brick:
			move $t0, $t3
			# this reduce the color by a factor of 2
			bgt $t5, 1, skip_modify_color
			andi $t3, $t3, 0xfefefe
			srl $t3, $t3, 1
			skip_modify_color:
				nop
			sw $t3, 0($a1)
			sw $t3, 4($a1)
			sw $t3, 8($a1)
			sw $t3, 12($a1)
			move $t3, $t0
	# else: addi $a1, $a1, 12
	next_brick:
		addi $a1, $a1, 16
		addi $t6, $t6, 1
		addi $a2, $a2, 4
		b for_draw_line
	done_draw_line: 
		jr $ra

# reduce_visibility(brick_address) -> success
# 	reduce the visibility of the brick from the memory.
# 	return 1 if successfully remove one brick
#
# 	Precondition: the value stored in brick_address is non-zero
reduce_visibility:
	# first, find the row and column of this brick
	addi $t0, $s0, 264 # position of the first brick
	sub $t7, $a0, $t0
	li $t8, 256 # line width
	div $t7, $t8
	mflo $t1 # store the row number
	mfhi $t7 # store the remainder
	li $t8, 16 # brick width
	div $t7, $t8
	mflo $t2 # store the ordinal number of the brick in this row

	# next, calculate the ordinal number of the brick
	mul $t1, $t1, 15
	add $t4, $t1, $t2 # store ordinal number

	# finally, change the visibility
	mul $t4, $t4, 4
	la $t5, bricks_visibility
	add $t5, $t5, $t4 # get the target brick visibility address
	lw $t3, 0($t5)
	srl $t3, $t3, 1
	sw $t3, 0($t5)

	# set results
	li $v0, 0
	bne $t3, $zero, reduce_epilogue
	addi $v0, $v0, 1
	# Epilogue
	reduce_epilogue:
		jr $ra

# display_single_number(start_address, num)
# 	display 0-9 with start_address as top left
# 	total 5 * 3 pixels
# 	helper function to display_score_number(start_address, num)
#
# 	Precondition: num is one of 0-9
display_single_number: # TODO: now is just a color block to test for other instructions
	li $t1, 0 # ith column gonna draw
	li $t2, 5
	for_display_number:
		slt $t9, $t1, $t2
		beqz $t9, done_display_number
		li $t3, 0xffffff
		# sw $t3, 0($a0)
		# sw $t3, 4($a0)
		# sw $t3, 8($a0)
		
		
		# check which row to display
		li $t0, 0
		beq $t1, $t0, first_row
		li $t0, 1
		beq $t1, $t0, second_row
		li $t0, 2
		beq $t1, $t0, third_row
		li $t0, 3
		beq $t1, $t0, fourth_row
		li $t0, 4
		beq $t1, $t0, fifth_row
		
		
		first_row:
			# if num = 0
			li $t0, 0
			beq $a1, $t0, display_full
			# if num = 1
			li $t0, 1
			beq $a1, $t0, display_3
			# if num = 2
			li $t0, 2
			beq $a1, $t0, display_full
			# if num = 3
			li $t0, 3
			beq $a1, $t0, display_full
			# if num = 4
			li $t0, 4
			beq $a1, $t0, display_13
			# if num > 4
			j display_full
			
			
		
		second_row:
			# if num = 0
			li $t0, 0
			beq $a1, $t0, display_13
			# if num = 4
			li $t0, 4
			beq $a1, $t0, display_13
			# if num = 1,2,3
			slt $t9, $a1, $t0
			bne $t9, $zero, display_3
			# if num = 7
			li $t0, 7
			beq $a1, $t0, display_3
			# if num = 5,6
			slt $t9, $a1, $t0
			bne $t9, $zero, display_1
			# if num = 8,9
			j display_13
			
		
		
		third_row:
			# if num = 0
			li $t0, 0
			beq $a1, $t0, display_13
			# if num = 1
			li $t0, 1
			beq $a1, $t0, display_3
			# if num = 7
			li $t0, 7
			beq $a1, $t0, display_3
			# if num = 2,3,4,5,6,8,9
			j display_full

		
		fourth_row:
			# if num = 0
			li $t0, 0
			beq $a1, $t0, display_13
			# if num = 2
			li $t0, 2
			beq $a1, $t0, display_1
			# if num = 6
			li $t0, 6
			beq $a1, $t0, display_13
			# if num = 8
			li $t0, 8
			beq $a1, $t0, display_13
			# if num = 1,3,4,5,7,9
			j display_3

		
		
		fifth_row:
			# if num = 1
			li $t0, 1
			beq $a1, $t0, display_3  
			# if num = 4
			li $t0, 4
			beq $a1, $t0, display_3
			# if num = 7
			li $t0, 7
			beq $a1, $t0, display_3
			# if num = 0,2,3,5,6,8,9
			j display_full
		
		
		
		display_full:
			sw $t3, 0($a0)
			sw $t3, 4($a0)
			sw $t3, 8($a0)
			j display_next_row
		display_13:
			sw $t3, 0($a0)
			sw $t3, 8($a0)
			j display_next_row
		display_1:
			sw $t3, 0($a0)
			j display_next_row
		display_3:
			sw $t3, 8($a0)
			j display_next_row
		
	display_next_row:
		addi $t1, $t1, 1
		addi $a0, $a0, 256
		b for_display_number
	done_display_number:
		jr $ra

# display_score_number(start_address, num)
#	display 0-90 with start address as top left
# 	total (2 * 3 + 1) * 5 = 35 pixels
#
#	Precondition: 0 <= num <= 90
display_score_number:
	li $t8, 10
	div $a1, $t8

	# save $ra
	addi $sp, $sp, -4
	sw $ra, 0($sp)
	# save start address
	addi $sp, $sp, -4
	sw $a0, 0($sp)
	# save remainder
	addi $sp, $sp, -4
	mfhi $t0
	sw $t0, 0($sp)
	mflo $a1

	# draw tens digit
	jal display_single_number
	# after that, draw the ones digit
	lw $a1, 0($sp)
	addi $sp, $sp, 4
	lw $a0, 0($sp)
	addi $sp, $sp, 4
	addi $a0, $a0, 16
	jal display_single_number
	# after the drawing, return back
	lw $ra, 0($sp)
	addi $sp, $sp, 4
	jr $ra

# remove_number(start_address)
#	remove the number display on this address
# 	for a total of 35 pixels
remove_number:
	li $t1, 0
	li $t2, 7
	for_remove_number:
		slt $t9, $t1, $t2
		beqz $t9, done_remove_number
		# clear one column
		sw $zero, 0($a0)
		sw $zero, 256($a0)
		sw $zero, 512($a0)
		sw $zero, 768($a0)
		sw $zero, 1024($a0)
		# update iteration number
		addi $t1, $t1, 1
		# move to the next column
		addi $a0, $a0, 4
		b for_remove_number
	done_remove_number:
		jr $ra

# clear_screen()
# 	clear the entire screen
clear_screen:
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
		jr $ra
