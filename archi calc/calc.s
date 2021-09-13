  %macro call_printf 2  
    pushad
    push %1
    push %2
    call printf
    add esp, 8   
    popad
  %endmacro
  
  %macro printToSTDERR 2 
    pushad
    mov eax, 4     
    mov ebx, 2      
    mov ecx, %1   
    mov edx, %2    
    int 0x80
    popad
  %endmacro

  %macro reset 0 
    mov eax, 0
    mov ebx, 0
    mov ecx, 0
    mov edx, 0
  %endmacro

  %macro free_opStack 0  
    pushad
    mov ecx, [curr_stack_len]
    dec ecx
    mov eax, [stack + 4*ecx]    
    %%remove_next_element:
      mov esi, [eax + 1]     
      pushad
      push eax
      call free
      add esp, 4
      popad
      mov eax, esi           
      cmp eax, 0
      jne %%remove_next_element
    %%done_remove:
      popad
      dec byte [curr_stack_len]    
  %endmacro


%macro calc_list_len 1     
  mov esi, 0
  mov ebx, %1                      
  %%inc_esi:
    inc esi
    mov %1, [%1 + 1]                        
    cmp %1, 0                               
    jne %%inc_esi
  mov %1, ebx
%endmacro

;converts the hexadecimal (one) digit in ebx to it's decimal representation:
  %macro to_binary 0
    mov ebx, 0
    mov bl, byte [eax]
    cmp bl, '9'
    jg %%comm
    sub ebx, '0'
    jmp %%end
    %%comm: 
      sub ebx, 55
      %%end:
  %endmacro
    

;converts the hexadecimal number in eax to it's decimal representation:
  %macro convert_two_hexadecimal_digits 0                                  
      mov ebx, dword [eax]
      cmp bh, '0'
      jge %%two
      to_binary
      mov [stack_size], bl
      jmp %%end
    %%two:
      to_binary
      mov edx, ebx
      inc eax
      to_binary
      shl edx, 4
      add edx, ebx ; edx = size from user
      mov [stack_size], dl
    %%end:
  %endmacro

; takes the char in bl and turn in to hex:
  %macro convert_bl_toHexa 0        
      cmp bl, 58
      jl .sub_0
      jge .sub_55
      .sub_0:
        sub bl, '0'
        jmp .end
      .sub_55:
        sub bl, 55
        jmp .end
      .end:
  %endmacro

; the addition operation while the carry != 0
  %macro add_digits 0            
      clc                                   ; clear carry flag
      %%add_next_two_digits:
        mov bl, byte [edi]                
        mov al, byte [edx]                 
        adc al, bl                        
        mov byte [edx], al                 
        mov edx, [edx+1]                    
        mov edi, [edi+1]                  
        loop %%add_next_two_digits, ecx
  %endmacro

  %macro create_carry_node 1      
      pushad
      push 5
      call malloc
      add esp, 4
      mov [carry_node_addr], eax
      popad
      mov ebx, [carry_node_addr]
      mov byte [ebx], 1
      mov dword [%1 + 1], ebx
  %endmacro

; swap between the tow elements in the top of the stack
  %macro xchg_elements 0                    
      mov eax, [curr_stack_len]
      dec eax
      mov edx, [stack + eax*4]
      dec eax
      mov ecx, [stack + eax*4]
      mov [stack + eax*4], edx
      inc eax
      mov [stack + eax*4], ecx

      mov esi, [input_len1]
      xchg [input_len2], esi
      xchg [input_len1], esi
  %endmacro

  %macro and_digits 0                   ; perfom and ecx times
    %%and_next_two_digits:
      mov bl, byte [edi]                 
      mov al, byte [edx]                
      and al, bl                   
      mov byte [edx], al                  
      mov edx, [edx+1]                   
      mov edi, [edi+1]               
      loop %%and_next_two_digits, ecx
  %endmacro

  %macro or_digits 0                    ; perfom or ecx times
      %%or_next_two_digits:
        mov bl, byte [edi]                
        mov al, byte [edx]            
        or al, bl                      
        mov byte [edx], al                
        mov edx, [edx+1]               
        mov edi, [edi+1]             
        loop %%or_next_two_digits, ecx
  %endmacro


;                                     ;;;;;;the sections start:
section .rodata
  
  format_string:                      db "%s", 0
  format_digit:                       db "%d", 0
  format_hex:                         db "%02X", 0
  format_hex_no_zero:                 db "%X", 0
  calc:                               db "calc: ", 0
  operand_error_msg:                  db "Error: Operand Stack Overflow", 10, 0
  operator_error_msg:                 db "Error: Insufficient Number of Arguments on Stack", 10, 0
  endl:                               db 10, 0             ; '\n' + null terminated
  sdebug:                             db "   Debug option is on - the last operand pushed to the stack: ",0
  s_size:                             db "The size of the operand stack is: ", 0

section .bss          
 
  stack_size:                         resb 1
  error_num:                          resb 1
  num:                                resb 4
  debug_mode:                         resb 1
  carry_node_addr:                    resb 4
  curr_stack_len:                     resb 10             ; number of elements currently in stack
  num_of_operations:                  resb 10
  ;the given numbers:
  
  stack:                              resb 255            ; the maximal size the operand stack can be: 0xFF 
  input:                              resb 81             ; the maximal length of the input line + null terminated
  input_len1:                         resb 80             ; the maximal length of the input line + null terminated
  input_len2:                         resb 80             ; the maximal length of the input line + null terminated

section .data
  backup_ebp:                         db 4
  backup_esp:                         db 4
  
section .text
; the allowed C functions to use:
  align 16
  global main
  extern printf
  extern malloc 
  extern free 
  extern gets  
     
;                                   ;;;;;;;;;;;;;; the start of main ;;;;;;;;;;;;;;;;;;    
main:                                   

  mov ecx, [esp + 4]                            ; get the argc in the ecx reg
  mov edx, [esp + 8]                            ; get the **argv in the edx reg, [edx] = argv[0] , [[edx]] = argv[0][0]
  ;initilize the variables we defiened:
  mov [backup_ebp], ebp
  mov [backup_esp], esp 
  mov byte [curr_stack_len], 0
  mov byte [debug_mode], 0
  mov byte [num_of_operations], 0
  mov byte [stack_size], 5                       ; defult size
  cmp ecx, 2
  jl my_calc
  jg got3args

  mov eax, 0                  
  mov eax, [edx + 4]                              ; [edx] = *program name.  [edx + 4] = *first argument
                                                  ; now we have the size of the stack in the eax reg as a string
  cmp word [eax], '-d'                            ; debug mode is activated
  je check_debug_mode
    

  convert_two_hexadecimal_digits
  jmp my_calc
    
  check_debug_mode:
    mov byte [debug_mode], 1
    jmp start
  
  got3args:
    mov eax, [edx + 4]                            ; argv[1][0] = [edx + 4] 
    convert_two_hexadecimal_digits
    jmp check_debug_mode                          ; debug mode now

  
  start:
    
    cmp byte [debug_mode], 1
    jne my_calc
    
    pstderr:
      cmp byte [curr_stack_len], 0
      je my_calc                            
      printToSTDERR sdebug, 62             
      pushad
      mov eax, [curr_stack_len]
      dec eax
      mov edx, [stack + eax*4]
      
      call print_operand_err
      
      popad
      printToSTDERR endl, 2                 ; print '\n' + null at the end of the string

  my_calc:
    
    call_printf calc, format_string         ; print the prompt message of my calc
    
    pushad                                  
    push input
    call gets                               ; get the input from the user and save it in input
    add esp, 4                              ; clean the stack after caling gets()  
    popad

    cmp byte [input], 'q'             ; if 'q' received, then exit the calc
    je quit_the_calc 
    cmp byte [input], '+'             ; '+' operator
    je unsigned_addition 
    cmp byte [input], 'p'             ; 'p' operator
    je pop_and_print
    cmp byte [input], 'd'             ; 'd' operator
    je duplicate
    cmp byte [input], '&'             ; '&' operator
    je AND
    cmp byte [input], '|'             ; '|' operator
    je OR 
    cmp byte [input], 'n'             ; 'n' operator
    je number_of_hexa_digits 
    

  push_to_stack:
  
    reset
    mov bl, [stack_size]
    cmp byte [curr_stack_len], bl
    je print_operand_error_msg                ; curr_stack_len = 5, stack overflow.
    mov esi, 0                                ; esi = counter --> calculate length (excluding leading zeroes)
    mov edi, input                            ; edi = pointer to the input
    
    remove_leading_zeroes: 
      cmp byte [edi], 0                       ; input = '\0' (null)
      je remove_zeros
      cmp byte [edi], '0'
      jne non_zero_byte                       ; reached first non-zero char
      inc edi
      jmp remove_leading_zeroes
    
    remove_zeros:
      mov esi, 1
      dec edi
      mov ebx, edi                         
      jmp create_single_node

    non_zero_byte:
      mov ebx, edi        

    calc_len:                                
      cmp byte [edi], 0        
      je end_calc_len
      inc esi                               
      inc edi                              
      jmp calc_len

    end_calc_len:                        
      mov edx, 0  
      mov eax, esi
      mov ecx, 2 
      div ecx                         
      cmp edx, 0
      je else

    create_single_node:      
      mov ecx, esi            
      mov esi, 0          
      mov edi, ebx         
      mov ebx, 0        
      mov bl, [edi]       
      inc edi            
      convert_bl_toHexa
      jmp create_node
    
    else:
      mov ecx, esi            
      mov esi, 0           
      mov edi, ebx          

    iterate:             
      mov ebx, 0         
      mov bl, [edi]   
      convert_bl_toHexa
      inc edi               
      mov dl, [edi]       
      
      ; takes the char in dl and turn in to hex:
      cmp dl, 58            
      jl .subb_0
      jge .subb_55
      .subb_0:
        sub dl, '0'
        jmp .endd
      .subb_55:
        sub dl, 55
        jmp .endd
      .endd:

      inc edi             
      shl bl, 4           
      add bl, dl            
      dec ecx             
      jmp create_node       
    
    after_creation:
      loop iterate, ecx

    insert_linkedList_to_stack:   
      mov ebx, [curr_stack_len]      
      mov [stack + 4*ebx], eax     
      inc byte [curr_stack_len]       
      jmp start                  

    create_node:   
      push ecx               ; backup ecx
      push 5                 ; push first argument - request 5 bytes to be allocated
      call malloc
      add esp, 4        
      pop ecx                ; restore ecx
      mov byte [eax], 0
      mov dword [eax + 1], 0
      mov byte [eax], bl  
        
      cmp esi, 0       
      je first_Node      
      jne concat    
    
    first_Node:
      mov esi, eax       
      jmp after_creation
    
    concat:
      mov dword [eax + 1], esi
      mov esi, eax        
      jmp after_creation


  print_operator_error_msg: 
    inc byte [num_of_operations]
    call_printf operator_error_msg, format_string
    jmp start

  print_operand_error_msg: 
    inc byte [num_of_operations]  
    call_printf operand_error_msg, format_string 
    jmp start
  
 
;;;;;;;;;;;;;;;; unsigned_addition operation:
  unsigned_addition:
    cmp byte [curr_stack_len], 1
    jle print_operator_error_msg           
    
    inc byte [num_of_operations]  
    mov ecx, [curr_stack_len]                       ; ecx = num of elements
    dec ecx                                    
    mov edi, [stack + 4*ecx]                        ; edi = address of first node in stack[top]
    
    calc_list_len edi                 
    
    mov [input_len1], esi                           ; input_len1 = length of the list in stack[top]
    dec ecx                     
    mov edx, [stack + 4*ecx]                        ; edx = address of first node in stack[top-1]
    
    calc_list_len edx     
    
    mov [input_len2], esi                           ; input_len2 = length of the list in stack[top-1]
    mov ebx, [input_len1]                
    cmp ebx, [input_len2]
    jl case1                                      
    ja case3                                
    jmp case2                              

    case1:                                          ; input_len1 < input_len2
      mov ecx, [input_len1]                         ; perfom input_len1 iterations
      add_digits
      jnc end_case1
      .add_carry:
        add byte [edx], 1                           ; add carry to next node
        jnc end_case1
      .add_carry_to_next_node:                      ; if there's carry add to next node 
        cmp dword [edx+1], 0                        ; Is last node ?
        je .last_carry_node
        mov edx, [edx+1]                            ; get next
        jmp .add_carry
      .last_carry_node:
        create_carry_node edx
    end_case1:
      free_opStack   
      jmp start

    case2:
      mov ecx, [input_len1]                         ; perfom input_len1 iterations
      add_digits
      jnc end_case2
      .add_last_carry:
        mov ecx, [curr_stack_len]
        dec ecx
        dec ecx
        mov edx, [stack + 4*ecx]
      .get_next:
        cmp dword [edx+1], 0
        je .concat_here
        mov edx, [edx+1]                          
        jmp .get_next
      .concat_here:
        create_carry_node edx
    end_case2:
      free_opStack
      jmp start
    
    case3:                                            ; input_len1 (top) > input_len2

      xchg_elements

      mov ecx, [curr_stack_len]                       ; ecx = num of elements
      dec ecx                                       
      mov edi, [stack + 4*ecx]                        ; edi = address of first node in stack[top]
      dec ecx                                   
      mov edx, [stack + 4*ecx]                        ; edx = address of first node in stack[top-1]
      
      jmp case1

;;;;;;;;;;;;;;;;;;;;;; pop_and_print operation

  pop_and_print:
    reset
    cmp byte [curr_stack_len], 1
    jl print_operator_error_msg                       ; curr_stack_len < 1 
    
    inc byte [num_of_operations]  
    
    mov eax, [curr_stack_len]
    dec eax
    mov edx, [stack + 4*eax]                          ; edx = pointer to the first node
    
    call print_operand
    call_printf endl, format_string                   ; '\n'+ null terminated
    
    free_opStack                                      ; [curr_stack_len]--
    
    jmp my_calc

;;;;;;;;;;;;;;;;;;;;;; duplicate operation

  duplicate:
    reset

    cmp byte [curr_stack_len], 1
    jl print_operator_error_msg           
    
    mov bl, [stack_size]
    cmp byte [curr_stack_len], bl
    je print_operand_error_msg               
    
    inc byte [num_of_operations]  

    ; create the first node, and insert it to the top of the stack:

    push 5                                          
    call malloc                              
    add esp, 4                   
    mov byte [eax], 0
    mov dword [eax + 1], 0
    mov edx, [curr_stack_len]
    mov [stack + 4*edx], eax            
    dec edx
    mov ebx, [stack + 4*edx]    

    iterate_and_copy:
      mov ecx, 0
      mov cl, byte [ebx]         
      mov byte [eax], cl
      mov ebx, [ebx + 1]       
      cmp ebx, 0               
      je last_node

      mov esi, eax
      push edx
      push 5             
      
      call malloc        
      
      add esp, 4           
      pop edx
      mov byte [eax], 0
      mov dword [eax + 1], 0
      mov dword [esi + 1], eax  
      jmp iterate_and_copy
    
    last_node:
      inc byte [curr_stack_len]       
      jmp start                   
  

;;;;;;;;;;;;;;;;;;;;;; bitwise_and operation
  ; ‘&’ - bitwise AND, X&Y with X being the top of operand stack and Y the element next to x in the operand stack.
  ; pop two operands from the operand stack, and push the result.
  AND:
    reset
    cmp byte [curr_stack_len], 1
    jle print_operator_error_msg    
    inc byte [num_of_operations]  
    mov ecx, [curr_stack_len]        
    dec ecx                       
    mov edi, [stack + 4*ecx]       
    calc_list_len edi                 
    mov [input_len1], esi           
    dec ecx                   
    mov edx, [stack + 4*ecx]      
    calc_list_len edx     
    mov [input_len2], esi     
    mov ebx, [input_len1]          
    cmp ebx, [input_len2]
    jl .case1_and             
    jmp .case2_and               


    .case1_and:                             ; input_len1 < input_len2
      xchg_elements

      mov ecx, [curr_stack_len]         ; ecx = num of elements
      dec ecx                         
      mov edi, [stack + 4*ecx]          ; edi = address of first node in stack[top]
      dec ecx                        
      mov edx, [stack + 4*ecx]          ; edx = address of first node in stack[top-1]
    
    .case2_and:                         ; input_len1 >= input_len2
      mov ecx, [input_len2]             ; perfom input_len1 iterations
      and_digits
    
    .end: 
      free_opStack
      jmp start

;;;;;;;;;;;;;;;;;;;;;; bitwise_or operation
  ; ‘|’ - bitwise OR, X|Y with X being the top of operand stack and Y the element next to x in the operand stack.
  ; pop two operands from the operand stack, and push the result.
  OR:
    reset
    cmp byte [curr_stack_len], 1
    jle print_operator_error_msg  
    inc byte [num_of_operations]  
    mov ecx, [curr_stack_len]       
    dec ecx                      
    mov edi, [stack + 4*ecx]        
    calc_list_len edi                 
    mov [input_len1], esi             
    dec ecx                    
    mov edx, [stack + 4*ecx]    
    calc_list_len edx     
    mov [input_len2], esi          
    mov ebx, [input_len1]           
    cmp ebx, [input_len2]
    jle .case1_or                           ; input_len1 <= input_len2
    jmp .case2_or                           ; input_len1 > input_len2

    .case1_or:                              ; input_len1 <= input_len2
      mov ecx, [input_len1]                 ; perfom input_len1 iterations
      or_digits
      jmp .end

    .case2_or:                              ; input_len1 > input_len2

      xchg_elements
      
      mov ecx, [curr_stack_len]           ; ecx = num of elements
      dec ecx                       
      mov edi, [stack + 4*ecx]            ; edi = address of first node in stack[top]
      dec ecx                      
      mov edx, [stack + 4*ecx]            ; edx = address of first node in stack[top-1]
      
      jmp .case1_or
    
    .end: 
      free_opStack
      jmp start

;;;;;;;;;;;;;;;;;;;;;; number_of_hexa_digits operation
  number_of_hexa_digits:
  
    reset
    cmp byte [curr_stack_len], 1
    jl print_operator_error_msg 

    mov bl, [stack_size]
    cmp byte [curr_stack_len], bl
    je print_operand_error_msg     ; curr_stack_len = 5, stack overflow.
    
    inc byte [num_of_operations]  

    mov edx, [curr_stack_len]
    dec edx
    mov ebx, [stack + 4*edx]      
    mov eax, 0                

    .iterate:
      mov edx, 0
      mov dl, [ebx]               
      mov ecx, 0
      add cl, dl
      
      shr dl, 8               
      add eax, 2         
    
    .con1:
      mov ebx, [ebx+1]           
      cmp ebx, 0                  
      jne .iterate
      cmp ecx, 0x0000000F
      jg .con2
      dec eax
    
    .con2:
      free_opStack
    
    ; eax = number of hexadecimal digits in decimal
    ; now we convert it fom dic to hex

	  ; edx contain the reminder
    
    ;dic_to_hex:
      mov byte [input], 0			; null terminated
      mov ecx, 1					    ; number of digits + 1 (null terminated)
      mov ebx, 16
    loop2:
      mov edx, 0					    ; like cqd but for unsign number
      div ebx
      add dl, 48					    ; 48 == '0'
      cmp dl, 57
      jle cont
      add dl, 7
    cont: 
      mov byte [input+ecx], dl
      inc ecx
      cmp eax, 0
      jnz loop2
    ; 
      mov eax, ecx 				; length of an
      dec eax
      mov ebx, 0
      mov edx, 0
      shr ecx, 1
    reverse: 					  	; the number was stored in a reversed order, as a result we need to reverse it
      mov bl, byte [input+edx]
      xchg bl, byte [input+eax]
      xchg bl, byte [input+edx]
      inc edx
      dec eax
      loop reverse
    end:
      jmp push_to_stack

;;;;;;;;;;;;;;;;;;;;;; print_operand operation
  print_operand:   
    pushad
    mov ebx, 0
    
    .print_opStack:
      mov ecx, 0
      mov cl, [edx]             
      push ecx               
      inc ebx
      cmp dword [edx + 1], 0       ; check if we reached the end of the list 
      je .the_top_of_opStack
      mov edx, [edx + 1]           ; edx is now point to the next node
      jmp .print_opStack
    
    .the_top_of_opStack:
      ; print the first element with no leadin zeros:
      cmp ebx, 1                   ; edx = number of nodes on the list
      je .one_element
      pop edx                  
      cmp edx, 0
      je .dec_and_continue
      call_printf edx, format_hex_no_zero
      dec ebx
    
    .end_of_opStack:
      cmp ebx, 1                   ; edx = number of nodes on the list
      je .last_one
      pop edx            
      call_printf edx, format_hex  
      dec ebx
      jmp .end_of_opStack
    
    .dec_and_continue:
      dec ebx
      jmp .the_top_of_opStack
    
    .one_element:
      pop edx                   
      call_printf edx, format_hex_no_zero
      jmp .end
    
    .last_one:
      pop edx                   
      call_printf edx, format_hex
    
    .end:
      popad
      ret

;;;;;;;;;;;;;;;;;;;;;; print_operand_err operation
  print_operand_err: 
    pushad
    mov ebx, 0              
    .print_opStack:
      mov ecx, 0
      mov cl, [edx]              
      push ecx                
      inc ebx
      cmp dword [edx + 1], 0   
      je .end_of_opStack
      mov edx, [edx + 1]        
      jmp .print_opStack
    .end_of_opStack:
      cmp ebx, 0            
      je .end
      pop edx      
      mov eax, 0
      mov ecx, 4
    
    .shifting:
      shl dl, 1
      jc .case_1
      jnc .case_0
    
    .continue:
      loop .shifting, ecx
      jmp .printing
    
    .case_0:
      shl al, 1
      jmp .continue
    
    .case_1:
      shl al, 1
      inc al
      jmp .continue
    
    .printing:
      mov ecx, 4
    .shifting_back:
      shr dl, 1
      loop .shifting_back, ecx
        
    call convert_to_string
    
    mov byte [error_num], 0
    mov byte [error_num], al
    printToSTDERR error_num, 1
        
    mov eax, 0
    mov al, dl
    call convert_to_string
    mov byte [error_num], 0
    mov byte [error_num], al
    printToSTDERR error_num, 1
    dec ebx
    jmp .end_of_opStack

    .end:
      popad
      ret
  
  convert_to_string:                      ; convert from [num hex value] to [char hex value]
    cmp al, 9
    jle .add_0
    jg .add_55
    .add_0:
      add al, '0'
      jmp .end
    .add_55:
      add al, 55
      jmp .end
    .end:
      ret

;;;;;;;;;;;;;;;;;;;;;; quit_the_calc operation
  quit_the_calc:

  mov eax, [curr_stack_len]      
  cmp eax, 0 
  je end_loop
  
  stack_loop:               
    free_opStack
    dec eax
    cmp eax, 0
    jne stack_loop

  end_loop:          
    mov ebx, [num_of_operations]
    call_printf ebx, format_hex_no_zero
    call_printf endl, format_string             ; '\n' + null terminated
    mov esp, [backup_esp]
    mov ebp, [backup_ebp]
    ret
