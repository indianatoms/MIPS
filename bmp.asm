#description:  zrobic taka konwencja
#	sets the color of specified pixel
#arguments:
#	$a0 - x coordinate
#	$a1 - y coordinate - (0,0) - bottom left corner
#	$a2 - 0RGB - pixel color


#only 24-bits 600x50 pixels BMP files are supported
.eqv BMP_FILE_SIZE 90122
.eqv BYTES_PER_ROW 1800
.eqv BIN_FILE_SIZE 60	#in bytes

	.data
#space for the 600x50px 24-bits bmp image
.align 4
res:	.space 2
image:	.space BMP_FILE_SIZE

buffer:	.space BIN_FILE_SIZE

fname:	.asciiz "source.bmp"
fbin:	.asciiz "input.bin"
output:	.asciiz "output.bmp"

set_dir:	.asciiz	"set_direction "
move:		.asciiz	"move "
set_pos:	.asciiz	"set_position "
pen_state:	.asciiz	"pen_state "
colon:	.asciiz ":"
error:	.asciiz "Turtle reached file border \n"
	.text
main:
	jal	read_bmp
	jal 	read_bin
	jal	save_bmp

exit:	li 	$v0,10		#Terminate the program
	syscall

# ============================================================================
#s2 - current pen state
#s3 - current pen color	
#s4 - turtle direction
#s5 - current x pos
#s6 - current y pos

read_bin:
	sub 	$sp, $sp, 4		#push $ra to the stack
	sw 	$ra,4($sp)
	sub 	$sp, $sp, 4		#push $s1
	sw 	$s1, 4($sp)
		#open file
			li 	$v0, 	13
			la 	$a0, 	fbin		#file name 
			li 	$a1, 	0		#flags: 0-read file
			li 	$a2, 	0		#mode: ignored
		syscall
			move 	$s1, 	$v0     	# save the file descriptor
		
	#check for errors - if the file was opened

#read file
		li $v0, 14				
		move $a0, $s1
		la $a1, buffer
		li $a2, BIN_FILE_SIZE
		syscall
			
		move 	$t1, $0					#counter (do not modify outside the loop)
		move 	$t2, $0					#keeps start of instruction in bytes (do not modify outside the loop)


	pre_loop:
		add	$t2, $t2, $t1
		move 	$t1, $0					#reset counter
	loop:
		add	$t0, $t1, $t2 
		bgt	$t0, BIN_FILE_SIZE, loop_exit		#end of file
		beq	$t1, 2, end_of_instruction	
		
		addiu	$t1, $t1, 2
		j 	loop
		
	end_of_instruction:
		lb	$t3, buffer($t2)
		

		
		
		move	$t4, $t3

		sll	$t4, $t4, 24
		srl	$t3, $t4, 31				#t3 1 bit of command			
		sll	$t4, $t4, 1
		srl	$t4, $t4, 31				#t4 2 bit of command
		
		add 	$t0, $t3, $t4
		
		beq 	$t3, 1, first_bit_one 			#1-			
		beq	$t4, 0, set_direction_command 		#00
		j	set_position_command			#01
		
	first_bit_one:	#1-
		beq 	$t4, 1, move_command			#11
		j	pen_state_command			#10


	set_direction_command: 					#16 bit
		jal 	dir_com
		j	pre_loop
	move_command: 						#16 bit
		jal 	move_com
		j	pre_loop
	set_position_command: 					#32 bit
		jal 	pos_com
		j	pre_loop
	pen_state_command: 					#16 bit
		jal 	pen_com
		j	pre_loop

	loop_exit:
#close file
		li $v0, 16
		move $a0, $s1
			syscall
		
		lw $s1, 4($sp)		#restore (pop) $s1
		add $sp, $sp, 4
		lw $ra, 4($sp)		#restore (pop) $ra
		add $sp, $sp, 4
		jr $ra
	
# ============================================================================
dir_com: 
		li	$v0, 4					#Print command name
		la	$a0, set_dir		
		syscall
		
		add	$t9, $t2,1
		lb	$t3, buffer($t9)			#t3 - start of instruction(first word)
				
		sll	$t4, $t3, 30
		srl	$t4, $t4, 31				#t4 - d1 bit of command
		
		sll	$t3, $t3, 31
		srl	$t3, $t3, 31				#t3 - d0 bit of command
		

		add	$s4, $zero, $t4
		sll	$s4, $s4, 1
		add	$s4, $s4, $t3				#s4 - turtle direction


		
		
		
		jr $ra
# ============================================================================
move_com:
		li	$v0, 4			#Print command name
		la	$a0, move		
		syscall
		
		
		
		lb	$t3, buffer($t2)			#t3 - start of instruction(first word)
		#s7 - how many to move
		move 	$t0, $0					#set t0 to 0 
				
		

		sll	$t3, $t3, 30				#offset bits
		srl	$t4, $t3, 31				#t4 - m3 bit of command
		add	$t7, $t7, $t4				#add to move
		
		sll	$t7, $t7, 1				#shift move				
		sll	$t3, $t3, 1				#get next bit
		srl	$t4, $t3, 31				#t4 - m2 bit of command
		add	$t7, $t7, $t4				#add to move
		
		add	$t9, $t2,1
		lb	$t3, buffer($t9)			#t3 - start of instruction(first word)		
		
		sll	$t7, $t7, 1				#shift move
		sll	$t3, $t3, 24				#offset bits	
		srl	$t4, $t3, 31				#t4 - m9 bit of command
		add	$t7, $t7, $t4				#add to current move
	
	move_loop:
		sll	$t7, $t7, 1				#shift move				
		sll	$t3, $t3, 1				#get next bit
		srl	$t4, $t3, 31				#t4 - m9-4 bit of command
		add	$t7, $t7, $t4				#add to move
		
		beq	$t0, 6, move_loop_exit			#exit after 7 iterations
		add	$t0, $t0, 1				#advance iterations counter
		j move_loop
	move_loop_exit:

	
		move	$s7, $ra				#save ra for return later
	execute_move_loop:
		add	$a0, $zero, $s5				#set x
		add	$a1, $zero, $s6 			#set y
		bltz	$s5, execute_move_error			#error: x<0
		bge	$s5, 600, execute_move_error		#error: x>600
		bltz	$s6, execute_move_error			#error: y<0
		bge	$s6, 50, execute_move_error		#error: y>50
		add	$a2, $zero, $s3				#set color
		beqz	$s2, execute_move_paint			
	execute_move_continue:
		beqz	$t7, execute_move_loop_exit	
		beq	$s4, 3, move_right			
		beq	$s4, 2, move_down
		beq	$s4, 1, move_left
		beq	$s4, 0, move_up
	execute_move_continue2:
		
		sub	$t7, $t7, 1				#reduce move counter
		j 	execute_move_loop

	execute_move_paint:
		jal	put_pixel				#paint pixel
		j	execute_move_continue
		
	move_up:
		add	$s6, $s6, 1
		j	execute_move_continue2
	move_down:	
		sub	$s6, $s6, 1
		j	execute_move_continue2
	move_right:
		add	$s5, $s5, 1
		j	execute_move_continue2
	move_left:
		sub	$s5, $s5, 1
		j	execute_move_continue2

	execute_move_error:
		li	$v0, 4			#Print error message
		la	$a0, error	
		syscall
		
		move $t7, $0
        
        	beq    $s4, 3, move1_right            
        	beq    $s4, 2, move1_down
       		beq    $s4, 1, move1_left
        	beq    $s4, 0, move1_up
        move1_right:
            	sub    $s5, $s5, 1
             	j     execute_move_loop_exit
        move1_down:
            	add    $s6, $s6, 1
            	j     execute_move_loop_exit
        move1_left:
            	add    $s5, $s5, 1
            	j     execute_move_loop_exit
        move1_up:
            	sub    $s6, $s6, 1
		
	execute_move_loop_exit:	
		move	$ra, $s7				#restore ra saved before		
		jr	$ra
# ============================================================================
pos_com:
		li	$v0, 4			#Print command name
		la	$a0, set_pos		
		syscall

		#s6 - current y pos
		add	$t9, $t2,2
		lb	$t3, buffer($t9)			#t3 - start of instruction(first word)	
		move 	$t0, $0					#reset t0
				
		
		sll	$t3, $t3, 24				#offset bits
		srl	$t4, $t3, 31				#t4 - y5 bit of command
		add	$s6, $zero, $t4				#add to current y pos
	set_pos_loop:
		sll	$s6, $s6, 1				#shift y pos				
		sll	$t3, $t3, 1				#get next bit
		srl	$t4, $t3, 31				#t4 - y5-0 bit of command
		add	$s6, $s6, $t4				#add to current y pos
		
		beq	$t0, 4, set_pos_loop_exit		#exit after 5 iterations
		add	$t0, $t0, 1				#advance iterations counter
		j set_pos_loop
		
		
	set_pos_loop_exit:	
		
		add	$t9, $t2,2
		lb	$t3, buffer($t9)			#t3 - start of instruction(first word)	
		move 	$t0, $0					#set t0 to 0 	

		sll	$t3, $t3, 30				#offset bits
		srl	$t4, $t3, 31				#t4 - x1 bit of command
		add	$s5, $zero, $t4				#add to current x pos
		
		sll	$s5, $s5, 1				#shift y pos				
		sll	$t3, $t3, 1				#get next bit
		srl	$t4, $t3, 31				#t4 - x0 bit of command
		add	$s5, $s5, $t4				#add to current x pos
		
		sll	$s5, $s5, 1				#shift y pos	
		move 	$t0, $0					#set t0 to 0 
		addiu	$t9, $t2, 3				#t9 - is set to next word
		lb	$t3, buffer($t9)			#t3 - start of instruction(second word 2nd part)
		
		sll	$t3, $t3, 24				#offset bits	
		srl	$t4, $t3, 31				#t4 - x9 bit of command
		add	$s5, $s5, $t4				#add to current x pos

	set_pos_loop2:
		sll	$s5, $s5, 1				#shift y pos				
		sll	$t3, $t3, 1				#get next bit
		srl	$t4, $t3, 31				#t4 - x9-2 bit of command
		add	$s5, $s5, $t4				#add to current x pos
		
		beq	$t0, 6, set_pos_loop_exit2		#exit after 7 iterations
		add	$t0, $t0, 1				#advance iterations counter
		j set_pos_loop2
		
	set_pos_loop_exit2:
	
		addiu	$t1, $t1, 2	
		jr $ra
# ============================================================================
pen_com:
		li	$v0, 4			#Print command name
		la	$a0, pen_state		
		syscall
		
		lb	$t3, buffer($t2)			#t3 - start of instruction(first word)		

		sll	$t3, $t3, 27
		srl	$t3, $t3, 31				#t3 ud bit of command
		
		add	$s2, $zero, $t3				#s2 - current pen state 
		
		add	$t9, $t2,1
		lb	$t3, buffer($t9)			#t3 - start of instruction(first word + one byte)
		
		
		sll	$t3, $t3, 28
		srl	$t4, $t3, 31				#t3 ud bit of command
		
		add	$t8, $zero, $zero
		add	$t8, $t8, $t4				#add to current x pos
		
		
		add	$t0, $zero, $zero
	set_red_loop:
		sll	$t8, $t8, 1				#shift y pos				
		sll	$t3, $t3, 1				#get next bit
		srl	$t4, $t3, 31				#t4 - x9-2 bit of command
		add	$t8, $t8, $t4				#add to current x pos

				
		beq	$t0, 2, set_green		#exit after 3 iterations
		add	$t0, $t0, 1				#advance iterations counter
		j set_red_loop
	
	
	set_green:
		sll	$t8, $t8, 5				#t4 - x9-2 bit of command	
		add	$t9, $t2,1
		lb	$t3, buffer($t9)			#t3 - start of instruction(first word)
		
		sll	$t3, $t3, 24
		srl	$t4, $t3, 31				#t3 ud bit of command
		

		add	$t8, $t8, $t4				#add to current x pos
		add	$t0, $zero, $zero

	set_green_loop:	
		sll	$t8, $t8, 1				#shift y pos				
		sll	$t3, $t3, 1				#get next bit
		srl	$t4, $t3, 31				#t4 - x9-2 bit of command
		add	$t8, $t8, $t4				#add to current x pos

		
		beq	$t0, 2, set_blue			#exit after 3 iterations
		add	$t0, $t0, 1				#advance iterations counter
		j set_green_loop
		
	set_blue:
		sll	$t8, $t8, 5				#t4 - x9-2 bit of command	
		lb	$t3, buffer($t2)			#t3 - start of instruction(first word)

		
		sll	$t3, $t3, 28
		srl	$t4, $t3, 31				#t3 ud bit of command
		

		add	$t8, $t8, $t4				#add to current x pos
		add	$t0, $zero, $zero

	set_blue_loop:	
		sll	$t8, $t8, 1				#shift y pos				
		sll	$t3, $t3, 1				#get next bit
		srl	$t4, $t3, 31				#t4 - x9-2 bit of command
		add	$t8, $t8, $t4				#add to current x pos

		
		beq	$t0, 2, finish_setting_color		#exit after 3 iterations
		add	$t0, $t0, 1				#advance iterations counter
		j set_blue_loop
			
		
		

	finish_setting_color:
		sll	$t8, $t8, 4				#t4 - x9-2 bit of command	
		
		add	$s3, $zero, $t8				#s3 - color
		
		li    $v0, 4            #Print command name
        	la    $a0, colon    
       		syscall
        	li    $v0, 35            #Print command name
        	la    $a0, ($s3)        
        	syscall
        	li    $v0, 4            #Print command name
       		la    $a0, colon        
        	syscall

		
		jr $ra
# ============================================================================ od typa

read_bmp:
		sub $sp, $sp, 4		#push $ra to the stack
		sw $ra,4($sp)
		sub $sp, $sp, 4		#push $s1
		sw $s1, 4($sp)
	#open file
		li $v0, 13
			la $a0, fname		#file name 
			li $a1, 0		#flags: 0-read file
			li $a2, 0		#mode: ignored
			syscall
		move $s1, $v0      # save the file descriptor
		
	#check for errors - if the file was opened

	#read file
		li $v0, 14
		move $a0, $s1
		la $a1, image
		li $a2, BMP_FILE_SIZE
		syscall

	#close file
		li $v0, 16
		move $a0, $s1
			syscall
		
		lw $s1, 4($sp)		#restore (pop) $s1
		add $sp, $sp, 4
		lw $ra, 4($sp)		#restore (pop) $ra
		add $sp, $sp, 4
		jr $ra

# ============================================================================ od typa
save_bmp:
		sub $sp, $sp, 4		#push $ra to the stack
		sw $ra,4($sp)
		sub $sp, $sp, 4		#push $s1
		sw $s1, 4($sp)
	#open file
		li $v0, 13
			la $a0, output		#file name 
			li $a1, 1		#flags: 1-write file
			li $a2, 0		#mode: ignored
			syscall
		move $s1, $v0      # save the file descriptor
		
	#check for errors - if the file was opened

	#save file
		li $v0, 15
		move $a0, $s1
		la $a1, image
		li $a2, BMP_FILE_SIZE
		syscall

	#close file
		li $v0, 16
		move $a0, $s1
			syscall
		
		lw $s1, 4($sp)		#restore (pop) $s1
		add $sp, $sp, 4
		lw $ra, 4($sp)		#restore (pop) $ra
		add $sp, $sp, 4
		jr $ra

# ============================================================================ Od typa
put_pixel:
#description: 
#	sets the color of specified pixel
#arguments:
#	$a0 - x coordinate
#	$a1 - y coordinate - (0,0) - bottom left corner
#	$a2 - 0RGB - pixel color
		sub $sp, $sp, 4		#push $ra to the stack
		sw $ra,4($sp)

		la $t4, image + 10	#adress of file offset to pixel array
		lw $t5, ($t4)		#file offset to pixel array in $t2
		la $t4, image		#adress of bitmap
		add $t5, $t4, $t5	#adress of pixel array in $t2
		
		#pixel address calculation
		mul $t4, $a1, BYTES_PER_ROW #t1= y*BYTES_PER_ROW
		move $t3, $a0		
		sll $a0, $a0, 1
		add $t3, $t3, $a0	#$t3= 3*x
		add $t4, $t4, $t3	#$t4 = 3x + y*BYTES_PER_ROW
		add $t5, $t5, $t4	#pixel address 
		
		#set new color
		sb $a2,($t5)		#store B
		srl $a2,$a2,8
		sb $a2,1($t5)		#store G
		srl $a2,$a2,8
		sb $a2,2($t5)		#store R

		lw $ra, 4($sp)		#restore (pop) $ra
		add $sp, $sp, 4
		jr $ra
# ============================================================================ Od typa
get_pixel:
#description: 
#	returns color of specified pixel
#arguments:
#	$a0 - x coordinate
#	$a1 - y coordinate - (0,0) - bottom left corner
#return value:
#	$v0 - 0RGB - pixel color

		sub $sp, $sp, 4		#push $ra to the stack
		sw $ra,4($sp)

		la $t4, image + 10	#adress of file offset to pixel array
		lw $t5, ($t4)		#file offset to pixel array in $t5
		la $t4, image		#adress of bitmap
		add $t5, $t4, $t5	#adress of pixel array in $t5
		
		#pixel address calculation
		mul $t4, $a1, BYTES_PER_ROW #t1= y*BYTES_PER_ROW
		move $t3, $a0		
		sll $a0, $a0, 1
		add $t3, $t3, $a0	#$t3= 3*x
		add $t4, $t4, $t3	#$t4 = 3x + y*BYTES_PER_ROW
		add $t5, $t5, $t4	#pixel address 
		
		#get color
		lbu $v0,($t5)		#load B
		lbu $t4,1($t5)		#load G
		sll $t4,$t4,8
		or $v0, $v0, $t4
		lbu $t4,2($t5)		#load R
			sll $t4,$t4,16
		or $v0, $v0, $t4
						
		lw $ra, 4($sp)		#restore (pop) $ra
		add $sp, $sp, 4
		jr $ra

# ============================================================================
