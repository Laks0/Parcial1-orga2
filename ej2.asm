global mezclarColores

section .rodata
shufAscendente: dq 0x0706060503020201, 0x0F0E0E0D0B0A0A09
shufY1: dq 0xFF050406FF010002, 0xFF0D0C0EFF09080A
shufY2: dq 0xFF040605FF000201, 0xFF0C0E0DFF080A09
shufY3: dq 0xFF060504FF020100, 0xFF0E0D0CFF0A0908 ;(Pone los alfa en 0)
mascara: times 4 dd 0x0000FFFF

;########### SECCION DE TEXTO (PROGRAMA)
section .text

;void mezclarColores( uint8_t *X (rdi), uint8_t *Y (rdi), uint32_t width (rdx), uint32_t height (rcx));
mezclarColores:
    push rbp
    mov rbp, rsp

    shr rdx, 2 ; divido rdx por 4 porque vamos a agarrar de a 4 píxeles
    movdqu xmm8, [mascara]
    movdqu xmm7, [shufY1]
    movdqu xmm9, [shufY2]

    .cicloVertical:
        mov r8, rdx
        .cicloHorizontal:
            movdqu xmm0, [rdi] ; xmm0 = los 4 píxeles actuales (X[i...i+4])
            pxor xmm6, xmm6 ; xmm6 va a guardar el resultado (Y[i...i+4])

            ; Caso ascendiente
            movdqu xmm1, xmm0
            movdqu xmm2, [shufAscendente]
            pshufb xmm1, xmm2

            ; El shuf mueve los datos para transformar cada píxel (dw) como:
            ; | A B G R | A B G R | A B G R | A B G R | xmm0
            ; | A B B G | A B B G | A B B G | A B B G | xmm1

            movdqu xmm2, xmm0
            pcmpgtb xmm2, xmm1
            
            ; Ahora dado un píxel en xmm0, xmm2 guarda:
            ; | 0 0 (G > B) (R > G) |
            ; para ver si entran en esta guarda queremos que el píxel tenga la forma:
            ; | 0 0 FF FF |

            pcmpeqd xmm2, xmm8 ; ahora un píxel en xmm2 es FFFFFFFF <=> entra en la guarda
            movdqu xmm15, xmm2 ; guardo la máscara para después

            movdqu xmm3, xmm0 ; xmm3 va a guardar la mezcla de cada píxel si entrase en la guarda
            pshufb xmm3, xmm7

            pand xmm2, xmm3 ; 0 si no entra en la guarda, Y si entra
            paddd xmm6, xmm2

            ;----------------------------------------------------------------------------------------
            ; Caso descendiente
            movdqu xmm1, xmm0
            movdqu xmm2, [shufAscendente]
            pshufb xmm1, xmm2

            ; El shuf mueve los datos para transformar cada píxel (dw) como:
            ; | A B G R | A B G R | A B G R | A B G R | xmm0
            ; | A B B G | A B B G | A B B G | A B B G | xmm1

            pcmpgtb xmm1, xmm0
            
            ; Ahora dado un píxel en xmm0, xmm1 guarda:
            ; | 0 0 (G < B) (R < G) |
            ; para ver si entran en esta guarda queremos que el píxel tenga la forma:
            ; | 0 0 FF FF |

            pcmpeqd xmm1, xmm8 ; ahora un píxel en xmm1 es FFFFFFFF <=> entra en la guarda
            paddd xmm15, xmm1 ; agrego la máscara a la anterior para tener los que no entraron en ninguna guarda

            movdqu xmm3, xmm0
            pshufb xmm3, xmm9
            pand xmm1, xmm3 ; 0 si no entra en la guarda, Y si entra
            paddd xmm6, xmm1

            ;----------------------------------------------------------------------------------------
            ; Caso base

            ; Ahora solo hace falta poner los X sin el alfa en los píxeles que quedaron vacíos en xmm6
            ; xmm15 está guardando los píxeles que entraron a alguna guarda
            pandn xmm15, xmm15
            pand xmm15, xmm0 ; Ahora xmm15 guarda los X que no entraron a ninguna
            movdqu xmm14, [shufY3]
            pshufb xmm15, xmm14 ; le saco los alfa

            paddd xmm6, xmm15 ; los agrego a xmm6

            movdqu [rdi], xmm6 ; Escribimos a memoria

            add rdi, 16

        dec r8
        jnz .cicloHorizontal

    dec rcx
    jnz .cicloVertical

    pop rbp
    ret
