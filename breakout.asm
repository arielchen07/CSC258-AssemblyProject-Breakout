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
ROW_BRICKS: .word 16 # brick_size = 4, each row has 16 bricks
NUM_ROWS: 3

WALL_COLOR: .word 0x808080 # grey
BALL_COLOR: .word 0xffffff # white
PADDLE_COLOR: .word 0x55aaff # light blue
BRICKS_COLOR: 
	.word 0xff0000 # red
	.word 0xffa500 # orange
	.word 0xffff00 # yellow
	      

##############################################################################
# Mutable Data
##############################################################################
ball: .word 0x10009c80
paddle: .word 0x10009d80
bricks_visibility: .word 1:48 # 3 rows * 16 bricks each row; 1 = brick visible, 0 otherwise
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
	
	draw_bricks:
		lw $a0, BRICKS_COLOR # bricks color for this row
		lw $a1, ADDR_DSPL # wall bit address
		addi $a1, $a1, 260 # first brick address of first row 256+4
		lw $a2, bricks_visibility # visibiity of the first brick in first row
		
		#sw $a0, 0($t3) # store color argument
		#sw $a1, 0($t4) # store first brick address argument
		#sw $a2, 0($t5) # store first brick visibility argument
		addi $t1, $zero, 0 # ith row gonna draw
		lw $t2, NUM_ROWS # iteration number
		for_draw_lines:
			slt $t9, $t1, $t2
			beq $t9, $zero, done_draw_bricks
			jal draw_line
			addi $a0, $a0, 1 # color for next row
			addi $a1, $a1, 512 # first brick of next row
			addi $a2, $a2, 16 # first brick visibility of next row
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
    	j draw_screen
		
    	# below are different branch responses for different key inputs
    	respond_to_q:
    		j finish_program
		respond_to_blank:
			nop
		respond_to_r:
			j main
		respond_to_a:
			li $t0, 0x10009d0c # left most core can reach
			slt $t9, $t0, $s2
			beqz $t9,done_draw_paddle # omit move at the edge
			sw $zero, 8($s2)
			addi $s2, $s2, -4
			b done_respond
		respond_to_d:
			li $t0, 0x10009df0 # right most core can reach
			slt $t9, $s2, $t0
			beqz $t9,done_respond # omit move at the edge
			sw $zero, -8($s2)
			addi $s2, $s2, 4
			b done_respond
		done_respond:
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

    #5. Go back to 1
    b game_loop

finish_program:
	li $v0, 10
	syscall

##############################################################################
# Functions
##############################################################################
draw_line:
	addi $t1, $zero, 0 # i
	lw $t2, ROW_BRICKS # iteration number per row
	lw $t3, 0($a0) # store bricks color for this row
	lw $t4, 0($a1) # first brick address of this row
	lw $t5, 0($a2) # visibiity of the first brick in this row
	for_draw_line:
		slt $t9, $t1, $t2 # i < iteration num
		beq $t9, $zero, done_draw_line
		beqz $t5, else
		sw $t3, 0($t4)
		sw $t3, 4($t4)
		sw $t3, 8($t4)
		sw $t3, 12($t4)
		j next_brick
	else: addi $t4, $t4, 16
	next_brick:
		addi $t4, $t4, 4
		addi $t1, $t1, 1
		addi $t5, $t5, 1
		b for_draw_line
	done_draw_line: 
		jr $ra