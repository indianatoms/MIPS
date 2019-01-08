#change s's

#only 24-bits 600x50 pixels BMP files are supported
.eqv BMP_FILE_SIZE 90122
.eqv BYTES_PER_ROW 1800
.eqv BIN_FILE_SIZE 10	#in bytes

.data
#space for the 600x50px 24-bits bmp image
.align 4
res:	.space 2
image:	.space BMP_FILE_SIZE
buff:	.space BIN_FILE_SIZE

fname:	.asciiz "source.bmp"
fbin:	.asciiz "move0.bin"
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


#s2 - current pen state
#s3 - current pen color	
#s4 - turtle direction

##########################################################################################
read_bin:
	sub 	$sp, $sp, 4				#push $ra to the stack
	sw 	$ra,4($sp)
	sub 	$sp, $sp, 4				#push $s1
	sw 	$s1, 4($sp)
		#open file
			li 	$v0, 	13
			la 	$a0, 	fbin		#file name 
			li 	$a1, 	0		#flags: 0-read file
			li 	$a2, 	0		#mode: ignored
		syscall
			move 	$s1, 	$v0     	# save the file descriptor

#read file
		li $v0, 14				
		move $a0, $s1
		la $a1, buff
		li $a2, BIN_FILE_SIZE
		syscall
			
		move 	$t1, $0					#counter (do not modify outside the loop)
		move 	$t2, $0					#keeps start of instruction in bytes (do not modify outside the loop)

	pre_loop:
		add	$t2, $t2, $t1				#add file size
		move 	$t1, $0					#reset command length
	loop:
		add	$t0, $t1, $t2 
		bgt	$t0, BIN_FILE_SIZE, close_file		#end of file
		beq	$t1, 2, end_of_command	
		
		addiu	$t1, $t1, 2
		j 	loop
		
	end_of_command:
		lb	$t3, buff($t2)
				
		move	$t4, $t3
		
		sll	$t4, $t4, 24
		srl	$t3, $t4, 31				#t3 1st bit of command			
		sll	$t4, $t4, 1
		srl	$t4, $t4, 31				#t4 2nd bit of command
		
		add 	$t0, $t3, $t4
		
		beq 	$t3, 1, first_bit_one 			#1-			
		beq	$t4, 0, set_direction_command 		#00
		j	set_position_command			#01
		
	first_bit_one:	#1-
		beq 	$t4, 1, move_command			#11
		j	pen_state_command			#10


	set_direction_command: 					
		jal 	dir_com
		j	pre_loop
	move_command: 						
		jal 	move_com
		j	pre_loop
	set_position_command: #32
		jal 	pos_com
		j	pre_loop
	pen_state_command: 					
		jal 	pen_com
		j	pre_loop

	close_file:
#close file .bin
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
		add	$t9, $t2,1
		lb	$t3, buff($t9)			#t3 - start of instruction(first word)
				
		sll	$t4, $t3, 30
		srl	$t4, $t4, 30			#t4 - d1d0 
		
		la	$s4, ($t4)			#load d1d0 on s4

		jr $ra
# ============================================================================
move_com:
		lb	$t3, buff($t2)			#t3 - first byte

		
		sll	$t3, $t3, 30				#
		srl	$t4, $t3, 30				#t4 - m9m8
		add	$t7, $t7, $t4				#t7 - m9m8
		
		sll	$t7, $t7, 8				#shift move - m9m8 0000 0000				
		
		
		add	$t9, $t2,1
		lb	$t3, buff($t9)			# load nex byte		
		
		sll	$t3, $t3, 24				#get m9 bit
		srl	$t4, $t3, 24				#t4 - m9
		
		add	$t7, $t7, $t4				#t7 - m9m8 m7m6m5m4m3m2m1m0
		
		la	$s7, ($t7)				#s7 - m9m8 m7m6m5m4m3m2m1m0
		
		move	$s7, $ra				#save ra for return later / due to nested get_pixel

#s5 - current x pos
#s6 - current y pos		
		
	move_loop:
		#put red pixel in bottom left corner	
		#li	$a0, 0		#x
		#li	$a1, 0		#y
		#li 	$a2, 0x00FF0000	#color - 00RRGGBB
		#jal	put_pixel
	
		la	$a0,  ($s5)				#set x where to put pixel
		la	$a1,  ($s6) 				#set y where to put pixel	
		ble	$s5, -1, border_error			#if x<=-1 than error
		bgt	$s5, 599, border_error			#if x>=599 than error
		ble	$s6, -1, border_error			#if y<=-1 than error
		bgt	$s6, 49, border_error			#if y>=49 than error
		la	$a2, ($s3)				#set color
		beqz	$t7, move_exit				#prevent move 0
		beqz	$s2, paint				#check if pen state = 1
	move_pixel:
		beqz	$t7, move_exit				#if move = 0 end
		beq	$s4, 3, move_right			
		beq	$s4, 2, move_down
		beq	$s4, 1, move_left
		beq	$s4, 0, move_up
	proceed:
		
		sub	$t7, $t7, 1				#reduce move counter
		j 	move_loop

	paint:
		jal	put_pixel				#paint pixel
		j	move_pixel
		
	move_up:
		add	$s6, $s6, 1
		j	proceed
	move_down:	
		sub	$s6, $s6, 1
		j	proceed
	move_right:
		add	$s5, $s5, 1
		j	proceed
	move_left:
		sub	$s5, $s5, 1
		j	proceed

#in case of error
	border_error:
		li	$v0, 4			#Print error message
		la	$a0, error	
		syscall
		
		move 	$t7, $0
        
        	beq    $s4, 3, undo_right            
        	beq    $s4, 2, undo_down
       		beq    $s4, 1, undo_left
        	beq    $s4, 0, undo_up
        undo_right:
            	sub    $s5, $s5, 1
             	j     move_exit
        undo_down:
            	add    $s6, $s6, 1
            	j     move_exit
        undo_left:
            	add    $s5, $s5, 1
            	j     move_exit
        undo_up:
            	sub    $s6, $s6, 1
		
	move_exit:	
		move	$ra, $s7				#restore ra saved before		
		jr	$ra
# ============================================================================
pos_com:	#set position command
		#s6 - current y pos
		add	$t9, $t2,2
		lb	$t3, buff($t9)				#t3 - start of instruction(first word)	
				
	#set Y	
		sll	$t3, $t3, 24				#offset bits
		srl	$t4, $t3, 26				#t4 - y5y4y3y2y1y0
		la	$s6, ($t4)				#store y 0on #s6
		#add	$s6, $zero, $t4				#add to current y pos
	#set X	
		
		add	$t9, $t2,3
		lb	$t3, buff($t9)				#t3 - start of instruction(first word)	

		sll	$t3, $t3, 24				#offset bits
		srl	$t4, $t3, 24				#t4 - x7x6x5x4x3x2x1
		
		
		add	$t9, $t2,2
		lb	$t3, buff($t9)				#t3 - start of instruction(first word)					
	
		sll	$t3, $t3, 24				#offset bits
		srl	$t5, $t5, 30				#t5 - x9x8
		sll	$t5, $t5, 8				#t5 - x9x8 0000 0000
		add	$t5, $t4, $t5				#t5 - x9x8x7x6x5x4x3x2x1
		
		la	$s5, ($t5)
	
		addiu	$t1, $t1, 2				#add to bytes to counter cause set pos is 32 bit command
		jr $ra
# ============================================================================
pen_com:
		lb	$t3, buff($t2)				#t3 - 1st byte of instruction	
#set pen State
		sll	$t3, $t3, 27
		srl	$t3, $t3, 31				#t3 up/down
		
		la	$s2, ($t3)				#s2 = t3 - store up/down
#first we set green casue we use rgb color format
#set red	
		
		add	$t9, $t2,1
		lb	$t3, buff($t9)				#t3 - 2nd byte of instruction
			
		
		sll	$t3, $t3, 28
		srl	$t8, $t3, 28				#get current t4 - r3r2r1r0
		
#set green
	
	set_green:
		sll	$t8, $t8, 8				#add four zeros t4 - r3r2r1r0 0000
			
		add	$t9, $t2,1
		lb	$t3, buff($t9)				#load second byte
		
		sll	$t3, $t3, 24
		srl	$t4, $t3, 28				#t4 - g3g2g1g0
		
		add	$t8, $t8, $t4				#t8 - r3r2r1r0 0000 g3g2g1g0

#set blue
	set_blue:
		sll	$t8, $t8, 8				#at8 - r3r2r1r0 0000 g3g2g1g0 0000	
		lb	$t3, buff($t2)				#t3 - first byte


		sll	$t3, $t3, 28
		srl	$t4, $t3, 28				#t3 - b3b2b1b0
		
		add	$t8, $t8, $t4				#t8 - r3r2r1r0 0000 g3g2g1g0 0000 r3r2r1r0
		sll	$t8, $t8, 4				##t8 - r3r2r1r0 0000 g3g2g1g0 0000 r3r2r1r0 0000
#color seting finished
		la	$s3, ($t8)				#s3 - color made of r3r2r1r0 0000 g3g2g1g0 0000 b3b2b1b0 0000
		
		li $v0, 35
		la $a0, ($s3) 	
		syscall
		
		li $v0, 4
		la $a0, colon 	
		syscall
		
		jr $ra
# ============================================================================ OT
read_bmp:
		sub $sp, $sp, 4					#push $ra to the stack
		sw $ra,4($sp)
		sub $sp, $sp, 4					#push $s1
		sw $s1, 4($sp)
	#open file
		li $v0, 13
			la $a0, fname				#file name 
			li $a1, 0				#flags: 0-read file
			li $a2, 0				#mode: ignored
			syscall
		move $s1, $v0      				# save the file descriptor
		
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
		
		lw $s1, 4($sp)					#restore (pop) $s1
		add $sp, $sp, 4
		lw $ra, 4($sp)					#restore (pop) $ra
		add $sp, $sp, 4
		jr $ra

# ============================================================================ OT
save_bmp:
		sub $sp, $sp, 4					#push $ra to the stack
		sw $ra,4($sp)
		sub $sp, $sp, 4					#push $s1
		sw $s1, 4($sp)
	#open file
		li $v0, 13
			la $a0, output				#file name 
			li $a1, 1				#flags: 1-write file
			li $a2, 0				#mode: ignored
			syscall
		move $s1, $v0      				# save the file descriptor
		
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
		
		lw $s1, 4($sp)					#restore (pop) $s1
		add $sp, $sp, 4
		lw $ra, 4($sp)					#restore (pop) $ra
		add $sp, $sp, 4
		jr $ra

# ============================================================================ OT
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
# ============================================================================ OT
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
