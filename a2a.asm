format PE64
entry start

include "win64a.inc"

section ".text" code readable executable
start:
    sub rsp, 56

    call [GetCommandLineA]
    mov rcx, rax

    call parse_cla

    mov rcx, -11
    call [GetStdHandle]
    mov [stdout], rax

    mov rcx, filename
    mov rdx, GENERIC_READ
    mov r8, FILE_SHARE_READ
    xor r9, r9
    mov qword [rsp + 32], OPEN_EXISTING
    mov qword [rsp + 40], FILE_ATTRIBUTE_NORMAL
    mov qword [rsp + 48], 0
    call [CreateFileA]
    mov [file_ptr], rax

    mov rcx, [file_ptr]
    mov rdx, file_buffer
    mov r8, [buffer_size]
    mov r9, bytes_read
    xor rax, rax
    mov qword [rsp + 32], rax
    call [ReadFile]

    call parse_ppm

    mov rcx, [file_ptr]
    call [CloseHandle]

    add rsp, 56

    xor rax, rax
    ret

parse_cla:
    mov rsi, rcx

    .skip_program_name:
        cmp byte [rsi], ' '
        je .found_space
        inc rsi
        jmp .skip_program_name

    .found_space:
        inc rsi
        mov rdi, filename

    .parse_filename:
        cmp byte [rsi], ' '
        je .done_parse_filename
        cmp byte [rsi], 0
        je .done_parse_filename
        cmp byte [rsi], 9
        je .done_parse_filename
        cmp byte [rsi], 10
        je .done_parse_filename
        cmp byte [rsi], 13
        je .done_parse_filename

        mov al, byte [rsi]
        mov byte [rdi], al
        
        inc rsi
        inc rdi
        jmp .parse_filename

    .done_parse_filename:
        mov byte [rdi], 0
        inc rsi

    .copy_scale_factor:
        xor rax, rax
        xor rcx, rcx

    .parse_scale_factor:
        movzx rcx, byte [rsi]
        cmp cl, '0'
        jb .done
        cmp cl, '9'
        ja .done
        sub cl, '0'
        imul rax, 10
        add rax, rcx
        inc rsi
        jmp .parse_scale_factor

    .done:
        mov [scale_factor], rax
    ret

parse_ppm:
    mov rsi, file_buffer
    
    add rsi, 3

    call parse_number
    mov [image_width], rax

    call parse_number
    mov [image_height], rax

    call parse_number
    mov [maxval], rax

    call skip_space
    call parse_pixels
    ret

skip_space:
    .loop:
        cmp byte [rsi], ' '
        je .skip
        cmp byte [rsi], 9
        je .skip
        cmp byte [rsi], 10
        je .skip
        cmp byte [rsi], 13
        je .skip
        ret
    .skip:
        inc rsi
        jmp .loop

parse_number:
    xor rax, rax
    xor rcx, rcx

    call skip_space

    .parse_digits:
        movzx rcx, byte [rsi]
        cmp cl, '0'
        jb .done
        cmp cl, '9'
        ja .done
        sub cl, '0'
        imul rax, 10
        add rax, rcx
        inc rsi
        jmp .parse_digits

    .done:
        ret

parse_pixels:
    mov rbx, [image_height]
    xor r15, r15
    xor r14, r14

    .row_loop:
        mov r12, [image_width]
        xor r13, r13
        
        .col_loop:
            mov rax, rsi
            sub rax, file_buffer
            cmp rax, [bytes_read]
            jge .done
            
            movzx rax, byte [rsi]
            inc rsi
            movzx rcx, byte [rsi]
            inc rsi
            movzx rdx, byte [rsi]
            inc rsi
            
            mov rdi, [scale_factor]
            mov rax, r13
            xor rdx, rdx
            div rdi
            cmp rdx, 0
            jne .skip_pixel
            
            mov rax, r14
            xor rdx, rdx
            div rdi
            cmp rdx, 0
            jne .skip_pixel
            
            movzx rax, byte [rsi - 3]
            movzx rcx, byte [rsi - 2]
            movzx rdx, byte [rsi - 1]
            
            imul rax, 299
            imul rcx, 587
            imul rdx, 114
            
            add rax, rcx
            add rax, rdx
            
            xor rdx, rdx
            mov rcx, 1000
            div rcx

            call map

            mov [output_buffer + r15], al
            inc r15
            
        .skip_pixel:
            inc r13
            dec r12
            jnz .col_loop

        mov rax, r14
        xor rdx, rdx
        div qword [scale_factor]
        test rdx, rdx
        jnz .skip_newline
        
        mov byte [output_buffer + r15], 10
        inc r15
        
    .skip_newline:
        inc r14
        dec rbx
        jnz .row_loop

    .done:
        mov byte [output_buffer + r15], 0

        mov rcx, [stdout]
        mov rdx, output_buffer
        mov r8, r15
        xor r9, r9
        mov qword [rsp + 32], 0
        call [WriteFile]  
        ret

map:
    mov rcx, 255
    imul rax, ascii_chars_length
    xor rdx, rdx
    div rcx
    
    lea rbx, [ascii_chars]
    add rbx, rax
    mov al, byte [rbx]
    ret

section ".data" data readable writable
    ascii_chars db ".:-=+*#%@"
    ascii_chars_length = $ - ascii_chars
    scale_factor dq 1
    stdout dq ?
    file_ptr dq ?
    filename rb 32
    filename_length dq 0
    buffer_size dq 1048576
    file_buffer rb 1048576
    bytes_read dq 0
    image_width dq 0
    image_height dq 0
    maxval dq 0
    output_buffer rb 1048576

section "idata" import data readable
    library kernel32, "kernel32.dll"
    import kernel32, CreateFileA, "CreateFileA", \
                     GetStdHandle, "GetStdHandle", \
                     WriteFile, "WriteFile", \
                     ReadFile, "ReadFile", \
                     CloseHandle, "CloseHandle", \
                     GetCommandLineA, "GetCommandLineA"
