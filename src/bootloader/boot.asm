org 0x7C00
bits 16 

%define ENDL 0x0D, 0x0A

;bios parameter
jmp short start
nop 

bdb_oem: db 'MSWIN4.1' 
bdb_bytes_per_sector: dw 512
bdb_sectors_per_clusters: db 1
bdb_reserved_sectors: dw 1
bdb_fat_count: db 2
bdb_dir_entries_count: dw 0E0h
bdb_total_sectors: dw 2880
bdb_media_descriptor_type: db 0F0h
bdb_sectors_per_fat: dw 9
bdb_sectors_per_track: dw 18
bdb_heads: db 2
bdb_hidden_sectors: dd 0
bdb_large_sectors_count: dd 0

;extended boot record

ebr_drive_number: db 0
				  db 0 ;need to reserve a byte

ebr_signature: db 29h
ebr_volume_id: db 12h, 34h, 46h, 78h
ebr_volume_label: db 'ROM OS     ' ;needs to be 11 bytes
ebr_system_id: db 'FAT12   ' ;needs to be 8 bytes

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

	;read from the disk 
	; BIOS should set DL to drive number
	mov [ebr_drive_number], dl 

	mov ax, 1
	mov cl, 1
	mov bx, 0x7E00
	call disk_read

	;print
	mov si, test_msg
	call puts
	
	cli
	hlt

; the error handlers


floppy_error:
	mov si, msg_read_failed
	call puts
	jmp wait_key_and_reboot

wait_key_and_reboot:
	mov ah, 0
	int 16h ;waits for key
	jmp 0FFFFh:0 ;jumps to bios beginnings, should reboot

.halt: ; disables interupts so you can't get out
	cli
	hlt

;the disk routines

;convert LBA to CHS
;parameters:
; ax - LBA address
;returns:
; cx [bits 0-5]: sector number
; cx [bits 6-15]: cylindar
; dh: head

lba_to_chs: 
	push ax
	push dx

	xor dx, dx
	div word [bdb_sectors_per_track] ;ax = LBA / sectorsPerTrack
									 ;dx = LBA % sectorsPerTrack

	inc dx							 ;dx = LBA % sectorsPerTrack + 1 = cylinder
	mov cx, dx ;					 ;cx = sector

	xor dx, dx
	div word [bdb_heads]			 ;ax = (LBA / sectorsPerTrack) / Heads = cylinder
									 ;dx = (LBA / sectorsPerTracl) % Heads = head
	mov dh, dl
	mov ch, al
	shl ah, 6
	or cl, ah

	pop ax
	mov dl, al
	pop ax
	ret

; read sectors from disk
;parameters:
; ax: LBA address
; cl: number of sectors to read, max 128
; dl: drive number
; es:bx: memory address of storage place
disk_read:
	push ax
	push bx
	push cx
	push dx 
	push di

	push cx
	call lba_to_chs
	pop ax
	
	mov ah, 02h
	mov di, 3
.retry: ; floppy disks are unreliable, wiki says you should retry 3 times 
	pusha
	stc
	int 13h
	jnc .done

	;failed to read floppy
	popa
	call disk_read
	dec di
	test di, di 
	jnz .retry

.failed: 
	;failed 3 times


.done: 
	popa

	pop di
	pop dx
	pop cx
	pop bx
	pop ax
	ret

; resets the disk controller 
;parameters:
; dl: drive number
disk_reset:
	pusha
	mov ah, 0
	stc
	int 13h
	jc floppy_error
	popa
	ret


test_msg: db 'Hello world!', ENDL, 0
msg_read_failed: db 'Read from disk failed!', ENDL, 0

times 510-($-$$) db 0
dw 0AA55h
