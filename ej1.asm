section .rodata
	; Offsets de la lista
	%define liste_data_offset 0
	%define liste_next_offset 8
	%define liste_prev_offset 16
	%define list_first_offset 0
	%define list_last_offset 8

	; Offsets de los pagos
	%define monto_offset 0
	%define aprobado_offset 1
	%define pagador_offset 8
	%define cobrador_offset 16
	%define pago_size 24

	; Offsets de los splits
	%define cant_aprobados_offset 0
	%define cant_rechazados_offset 1
	%define l_aprobados_offset 8
	%define l_rechazados_offset 16
	%define split_size 24

section .text

global contar_pagos_aprobados_asm
global contar_pagos_rechazados_asm

global split_pagos_usuario_asm

extern malloc
extern free
extern strcmp


;########### SECCION DE TEXTO (PROGRAMA)
; uint8_t contar_pagos_aprobados_asm(list_t* pList (rdi) , char* usuario (rsi));
contar_pagos_aprobados_asm:
	push rbp
	mov rbp, rsp
	push r12
	push r13
	push r14
	sub rbp, 8

	; Pongo los datos en registros no volátiles para poder llamar funciones auxiliares
	xor r12, r12 ; r12 <- res

	mov r13, [rdi + list_first_offset] ; r13 ahora apunta al primer elemento de pList
	mov r14, rsi ; r14 <- usuario

	.cicloElementos:
	cmp r13, 0
	je .finElementos ; Si rdi == NULL, termina el ciclo
		mov rdi, r14
		mov rsi, [r13 + liste_data_offset] ; rsi es el pago actual que estamos viendo

		cmp byte [rsi + aprobado_offset], 0 ; pago.aprobado == 0?
		je .guardaElementos ; si no está aprobado, continue

		mov rsi, [rsi + cobrador_offset] ; rsi es el cobrador del pago actual
		call strcmp ; rax = 0 <=> (*rdi == *rsi) <=> el usuario es cobrador del pago actual
		cmp rax, 0
		jne .guardaElementos ; si el usuario no es cobrador, continue

		; Acá el pago está aprobado y lo cobró el usuario
		inc r12		

	.guardaElementos:
	mov r13, [r13 + liste_next_offset]
	jmp .cicloElementos


	.finElementos:

	mov rax, r12

	add rbp, 8
	pop r14
	pop r13
	pop r12
	pop rbp
	ret

; uint8_t contar_pagos_rechazados_asm(list_t* pList, char* usuario);
; (igual a aprobados)
contar_pagos_rechazados_asm:
	push rbp
	mov rbp, rsp
	push r12
	push r13
	push r14
	sub rbp, 8

	; Pongo los datos en registros no volátiles para poder llamar funciones auxiliares
	xor r12, r12 ; r12 <- res

	mov r13, [rdi + list_first_offset] ; r13 ahora apunta al primer elemento de pList
	mov r14, rsi ; r14 <- usuario

	.cicloElementos:
	cmp r13, 0
	je .finElementos ; Si rdi == NULL, termina el ciclo
		mov rdi, r14
		mov rsi, [r13 + liste_data_offset] ; rsi es el pago actual que estamos viendo

		cmp byte [rsi + aprobado_offset], 0 ; pago.aprobado == 0?
		jne .guardaElementos ; si está aprobado, continue

		mov rsi, [rsi + cobrador_offset] ; rsi es el cobrador del pago actual
		call strcmp ; rax = 0 <=> (*rdi == *rsi) <=> el usuario es cobrador del pago actual
		cmp rax, 0
		jne .guardaElementos ; si el usuario no es cobrador, continue

		; Acá el pago está aprobado y lo cobró el usuario
		inc r12		

	.guardaElementos:
	mov r13, [r13 + liste_next_offset]
	jmp .cicloElementos


	.finElementos:

	mov rax, r12

	add rbp, 8
	pop r14
	pop r13
	pop r12
	pop rbp
	ret

; pagoSplitted_t* split_pagos_usuario_asm(list_t* pList (rdi), char* usuario (rsi));
split_pagos_usuario_asm:
	push rbp
	mov rbp, rsp
	push rbx
	push r12
	push r13
	push r14
	push r15
	sub rbp, 8

	mov r12, rdi ; r12 <- pList
	mov r13, rsi ; r13 <- usuario

	call contar_pagos_aprobados_asm
	mov r14, rax ; r14 <- cant_aprobados

	mov rdi, r12
	mov rsi, r13
	call contar_pagos_rechazados_asm
	mov r15, rax ; r15 <- cant_rechazados

	; rax = malloc(sizeof(pagoSplitted_t));
	mov rdi, split_size
	call malloc

	; pongo los valores de la cantidad de aprobados y rechazados en memoria
	mov byte [rax + cant_aprobados_offset], r14b
	mov byte [rax + cant_rechazados_offset], r15b

	mov rbx, rax ; rbx es el puntero al split

	mov rdi, r14
	shr rdi, 3 ; multiplico por 8 porque es el tamaño de un puntero
	call malloc ; pido memoria para el puntero de aprobados
	mov [rbx + l_aprobados_offset], rax ; pongo el puntero a la lista en memoria

	mov r14, rax ; r14 <- aprobados

	mov rdi, r15
	shr rdi, 3 ; multiplico por 8 porque es el tamaño de un puntero
	call malloc ; pido memoria para el puntero de rechazados
	mov [rbx + l_rechazados_offset], rax ; pongo el puntero a la lista en memoria

	mov r15, rax ; r15 <- rechazados

	mov r12, [r12 + list_first_offset] ; r12 = elem
	.cicloLista:
		cmp r12, 0
		je .finLista

		mov rdi, [r12 + liste_data_offset] ; rdi = pago
		mov rdi, [rdi + cobrador_offset] ; rdi = pago->cobrador
		mov rsi, r13
		call strcmp
		cmp rax, 0 ; si pago->cobrador != usuario
		jne .next ; continue

		mov rdi, [r12 + liste_data_offset] ; rdi = pago
		mov byte sil, [rdi + aprobado_offset] ; rsi = pago->aprobado
		cmp sil, 0
		je .rechazado
		mov [r14], rdi ; *aprobados = pago
		add r14, 8 ; aprobados++
		jmp .next

		.rechazado:
		mov [r15], rdi ; *rechazados = pago
		add r15, 8 ; rechazados++
		jmp .next

	.next: 
		mov r12, [r12 + liste_next_offset] ; elem = elem->next
		jmp .cicloLista
	.finLista:

	mov rax, rbx ; retorno el split

	add rbp, 8
	pop r15
	pop r14
	pop r13
	pop r12
	pop rbx
	pop rbp
	ret
