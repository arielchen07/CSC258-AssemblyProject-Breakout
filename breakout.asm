################ CSC258H1F Fall 2022 Assembly Final Project ##################
# This file contains our implementation of Breakout.
#
# Student 1: Sirui Chen, Student Number
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

WALL_COLOR: .word 0x808080 # grey
BALL_COLOR: .word 0xffffff # white
PADDLE_COLOR: .word 0x55aaff # light blue

##############################################################################
# Mutable Data
##############################################################################
ball: .word 0x10009c80
paddle: .word 0x10009d80
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
	sleep (1000)

game_loop:
	# 1a. Check if key has been pressed
	keyboard_check:
		lw $t0, ADDR_KBRD               # $t0 = base address for keyboard
    	lw $t8, 0($t0)                  # Load first word from keyboard
		beq $t8, 1, keyboard_input      # If first word 1, key is pressed
    	b draw_screen

    # 1b. Check which key has been pressed
    keyboard_input:
    	lw $a0, 4($t0)                  # Load second word from keyboard
		beq $a0, 0x20, respond_to_blank # start the game
    	beq $a0, 0x71, respond_to_q     # Check if the key q was pressed (quit)
    	beq $a0, 0x72, respond_to_r		 # Check if the key r was pressed (restart)
		beq $a0, 0x61, respond_to_a		# move paddle to the left
		beq $a0, 0x64, respond_to_d		# move paddle to the right

		li $v0, 1                       # ask system to print $a0
    	syscall
    	b draw_screen
		
    	# below are different branch responses for different key inputs
    	respond_to_q:
    		j finish_program
		respond_to_blank:
			nop
		respond_to_r:
			nop
		respond_to_a:
			nop
		respond_to_d:
			nop

    # 2a. Check for collisions
	# 2b. Update locations (paddle, ball)
	# 3. Draw the screen
	draw_screen:
		draw_ball:
			lw $t3, BALL_COLOR
			sw $t3, 0($s1)
		draw_paddle:
			lw $t3, PADDLE_COLOR
			li $t1, 0
			li $t2, 5
			addi $t4, $s2, -8
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

    #5. Go back to 1
    b game_loop

finish_program:
	li $v0, 10
	syscall

##############################################################################
# Functions
##############################################################################
