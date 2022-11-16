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

##############################################################################
# Mutable Data
##############################################################################

##############################################################################
# Code
##############################################################################
	.text
	.globl main

	# Run the Brick Breaker game.
main:
    # Initialize the game
draw_background:
	draw_top_wall:
		lw $s0, ADDR_DSPL
		addi $t1, $zero, 0 # i
		lw $t2, ROW_WALL # iteration number
		lw $t3, WALL_COLOR # wall color
		lw $t4, ADDR_DSPL # wall bit address
		for_draw_top_wall:
			beq $t1, $t2, draw_left_wall
			sw $t3, 0($t4)
			addi $t4, $t4, 4
			addi $t1, $t1, 1
			b for_draw_top_wall
	draw_left_wall:
		addi $t1, $zero, 0 # i
		lw $t2, COLUMN_WALL # iteration number
		lw $t4, ADDR_DSPL # wall bit address
		for_draw_left_wall:
			beq $t1, $t2, draw_right_wall
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
			beq $t1, $t2, done_draw_wall
			sw $t3, 0($t4)
			addi $t4, $t4, 256
			addi $t1, $t1, 1
			b for_draw_right_wall
	done_draw_wall:
		nop

game_loop:
	# 1a. Check if key has been pressed
    # 1b. Check which key has been pressed
    # 2a. Check for collisions
	# 2b. Update locations (paddle, ball)
	# 3. Draw the screen
	# 4. Sleep

    #5. Go back to 1
    b game_loop
