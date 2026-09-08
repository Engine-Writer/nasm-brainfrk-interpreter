section .bss
myMemory: resb 16384  ; 4096 * 4 = 4 pages of RAM
statbuf: resb 144

section .text
global _start

_start:
    mov rax, [rsp]  ; argc
    cmp rax, 2
    jl  end_process  ; Error- No Code

    mov rsi, [rsp+16]  ; argv[1] = file path

    mov rax, 2  ; open(argv[1], O_RDONLY, 0)
    mov rdi, rsi
    xor rsi, rsi
    xor rdx, rdx
    syscall
    test rax, rax
    js  end_process
    mov r12, rax  ; r12 = fd

    mov rax, 5  ; fstat(fd, &statbuf)
    mov rdi, r12
    lea rsi, [rel statbuf]
    syscall
    test rax, rax
    js end_process

    mov r13, [rel statbuf + 48]  ; r13 = file size (BF source length)
    mov rax, 9  ; mmap(NULL, size, PROT_READ, MAP_PRIVATE, fd, 0)
    xor rdi, rdi
    mov rsi, r13
    mov rdx, 1
    mov r10, 2
    mov r8, r12
    xor r9, r9
    syscall
    test rax, rax
    js  end_process
    mov r14, rax  ; r14 = pointer to BF source in memory

    mov rax, 3  ; fd no longer needed
    mov rdi, r12
    syscall  ; r14 = BF source pointer, r13 = BF source length
    xor r8, r8
    mov r9, r14
    lea r10, [r14 + r13]  ; ... one of the ways to do fast arithmatic of all time

    call main_interpreter_fn
    jmp end_process

main_interpreter_fn:
    ; RBP stack frame omitted for better perf
    push r9

.main_interpreter_loop:
    cmp r9, r10
    jae .return_end_fncshn

    and r8, 0x3FFF  ; fym talkin bout some "aSseMBly iSN'T meMORY sAfE"
    lea rsi, [myMemory + r8]
    mov al, [r9]

    ; BIG ASS IF-ELSE. INCOMING! (less bytes than switch-case ig /shrug)
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
    test ah, ah
    jz .passthru
    inc r9
    call main_interpreter_fn
    jmp .end_of_all_cases
.passthru: mov rcx, 1
.passthru_loop: inc r9
    cmp r9, r10
    jae .return_end_fncshn
    cmp byte [r9], '['
    jne .skipIncRCX
    inc rcx
.skipIncRCX: cmp byte [r9], ']'
    jne .skipDecRCX
    dec rcx
.skipDecRCX: test rcx, rcx
    jnz .passthru_loop
    jmp .end_of_all_cases

.next_case5:
    cmp al, ']'
    jne .next_case6

    mov ah, [rsi]
    test ah, ah
    jz .return_end_fncshn

    mov r9, [rsp] ; Loop the f*** back
    jmp .main_interpreter_loop  ; YOU HAVE NO IDEA HOW FUCKING ANNOYING THIS WAS TO DEBUG

.next_case6:  ; Wouldn't it be crazy if I got all the registers perfectly setup for the next 2 cases... oh wait
    cmp al, '.'
    jne .next_case7
    mov rax, 1  ; sys_write
    mov rdi, 1  ; stdout FD
    syscall
    jmp .end_of_all_cases
.next_case7:
    cmp al, ','
    jne .end_of_all_cases
    xor rax, rax  ; sys_read
    xor rdi, rdi  ; fd = stdin
    syscall  ; its like the stars aligned

.end_of_all_cases:  inc r9
    jmp .main_interpreter_loop

.return_end_fncshn:  add rsp, 8
    ret

end_process:  mov rax, 60
    xor rdi, rdi
    syscall
