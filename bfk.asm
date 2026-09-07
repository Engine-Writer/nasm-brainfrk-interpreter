section .bss
statbuf: 
  resb 144

section .data
; Allocate 2 pages of RAM for BrFK interpreter
; BTW must be init at 0 so not BSS
myMemory:
  times 8192 db 0  ; 4096 * 2

section .text
global _start

; Takes in [RSI] as POINTER to str and RCX as MAX length
; returns strlen as RCX
; ... I was too lazy to stack frame XD
strnlen:
    xchg rsi, rdi  ; RSI makes WAY MORE SENSE for scasb than RDI IMO but cursed intel microcode
    push rax
    push rdi
    push rdi

    ; Actual code
    xor al, al
    repne scasb  ; scan [RDI] for null byte
    
    pop rax
    mov rcx, rdi
    sub rcx, rax
    dec rcx

    ; restore
    pop rdi
    pop rax

    xchg rsi, rdi
    ret


_start:
    mov rax, [rsp]          ; argc
    cmp rax, 2
    jl  end_process

    mov rsi, [rsp+16]      ; argv[1] = file path

    ; open(argv[1], O_RDONLY, 0)
    mov rax, 2
    mov rdi, rsi
    xor rsi, rsi
    xor rdx, rdx
    syscall
    test rax, rax
    js  end_process
    mov r12, rax           ; r12 = fd

    ; fstat(fd, &statbuf)
    mov rax, 5
    mov rdi, r12
    lea rsi, [rel statbuf]
    syscall
    test rax, rax
    js  end_process

    mov r13, [rel statbuf + 48]   ; r13 = file size (BF source length)

    ; mmap(NULL, size, PROT_READ, MAP_PRIVATE, fd, 0)
    mov rax, 9
    xor rdi, rdi
    mov rsi, r13
    mov rdx, 1
    mov r10, 2
    mov r8, r12
    xor r9, r9
    syscall
    test rax, rax
    js  end_process
    mov r14, rax           ; r14 = pointer to BF source in memory

    ; fd no longer needed
    mov rax, 3
    mov rdi, r12
    syscall

    ; r14 = BF source pointer, r13 = BF source length`


    ; Set flags to the only acceptable state
    cld
    clc
    
    mov r8, 0
    mov r9, r14
    lea r10, [r14 + r13]  ; one of the ways to do fast arithmatic of all time

    call main_interpreter_fn
    jmp end_process

main_interpreter_fn:
    push rbp
    mov rbp, rsp
    sub rsp, 8
    mov [rbp - 8], r10
    push r9

.main_interpreter_loop:
    lea rdi, [r9]
    and r8, 0x1FFF
    lea rsi, [myMemory + r8]
    mov al, [rdi]
    
    ; BIG ASS SWITCH-CASE. INCOMING!
.next_case0:
    cmp al, '<'
    jne .next_case1

    dec r8
    jmp .end_of_all_cases
.next_case1:
    cmp al, '>'
    jne .next_case2

    inc r8
    jmp .end_of_all_cases


.next_case2:
    cmp al, '+'
    jne .next_case3

    inc byte [rsi]
    jmp .end_of_all_cases
.next_case3:
    cmp al, '-'
    jne .next_case4

    dec byte [rsi]
    jmp .end_of_all_cases


.next_case4:
    cmp al, '['
    jne .next_case5

    ; welp
    mov ah, [rsi]
    test ah, 0xFF
    jz .end_of_all_cases
    inc r9
    call main_interpreter_fn
    jmp .end_of_all_cases
.next_case5:
    cmp al, ']'
    jne .next_case6

    mov ah, [rsi]
    test ah, 0xFF
    jz .return_end_fncshn

    mov r9, [rbp-16] ; Loop the f*** back
    jmp .main_interpreter_loop  ; YOU HAVE NO IDEA HOW FUCKING ANNOYING THIS WAS TO DEBUG


.next_case6:
    cmp al, '.'
    jne .next_case7
    
    ; Wouldnt it be so funny if all of the parameters are magically set correctly?
    ; Oh wait
    call .dotfunction  ; get it?? cuz this is the `.` case and the fn starts with a `.`? not funny? ok
    jmp .end_of_all_cases
.next_case7:
    cmp al, ','
    jne .end_of_all_cases

    call .commafunction


.end_of_all_cases:
    inc r9
    cmp r9, r10
    jb .main_interpreter_loop

.return_end_fncshn:
    add rsp, 16
    pop rbp
    ret

.dotfunction:  ; PLEASE SET RSI
    push rdx
    push rax
    push rdi

    mov rdx, 1  ; length
    mov rax, 1  ; sys_write
    mov rdi, 1  ; stdout FD
    syscall
    
    pop rdi
    pop rax
    pop rdx
    ret

.commafunction:  ; PLEASE SET RSI
    push rdx
    push rax
    push rdi

    mov rdx, 1  ; length = 1 byte
    mov rax, 0  ; sys_read
    mov rdi, 0  ; fd = stdin
    syscall
    
    pop rdi
    pop rax
    pop rdx
    ret

end_process:
    mov rax, 60
    xor rdi, rdi
    syscall
