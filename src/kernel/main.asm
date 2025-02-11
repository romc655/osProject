org 0x7C00
bits 16 

%define ENDL 0x0D, 0x0A

start:
	jmp main


puts: ;put string
	push si
	push ax 

.loop:
	lodsb
	or al, al
	jz .done

	mov ah, 0x0e
	mov bh, 0
	int 0x10
	
	jmp .loop
	
.done:
	pop ax 
	pop si
	ret

main:

	;setup the data segments
	mov ax, 0
	mov ds, ax
	mov es, ax

	;setup the stack 
	mov ss, ax
	mov sp, 0x7C00

	;print
	mov si, test_msg
	call puts
	
	hlt

.halt:
	jmp .halt

test_msg: db 'Hello world!', ENDL, 0

times 510-($-$$) db 0
dw 0AA55h
