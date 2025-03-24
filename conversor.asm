.data
    mensaje_entrada:    .asciiz "\nIngrese un número (formato: decimal o hexadecimal [+/-][0-9/A-F]...[,][0-9/A-F]{0,2}, ej: 9, F, +1A,FF, -5,25): "
    error_formato:      .asciiz "Formato inválido. Sólo decimales o hexadecimales\n"
    error_longitud:     .asciiz "Demasiado largo \n"
    resultado_msg:      .asciiz "\n Transformación a IEEE 754: "
    buffer:             .space 20
    mensaje_normalizado:.asciiz "\nForma normalizada del valor ingresado: "
    por_dos:            .asciiz " × 2^"
    espacio:            .asciiz " "
    nueva_linea:        .asciiz "\n"
    uno_punto:          .asciiz "1."
    cero_punto:         .asciiz "0."

.text
.globl main

main:
    # Entrada del usuario
    li $v0, 4
    la $a0, mensaje_entrada
    syscall
    li $v0, 8
    la $a0, buffer
    li $a1, 20
    syscall

    # Registros
    la $s0, buffer        # pointer al bufferr
    li $s1, 0             # signo (-1, +0) 
    li $s2, 0             # parte entera del numero
    li $s3, 0             # parte fraccionaria (si la hay,)
    li $s4, 0             # exponente
    li $s5, 0             # es hexadecimal? (0 no, 1 si) 

    # Que signo tiene / si no hay signo, no se modifica $s0
    lb $t0, 0($s0)
    beq $t0, '+', tiene_signo_positivo
    beq $t0, '-', tiene_signo_negativo
    
    # primer digito: caracter valido?
    blt $t0, '0', error_formato_entrada  # menor q 0
    ble $t0, '9', es_numero_sin_signo    # digito 0-9
    blt $t0, 'A', error_formato_entrada  # si está entre 9 y A es invalido (basicamente, si es 10)
    ble $t0, 'F', es_hex_sin_signo       # si es una letra hex (A-F)
    j error_formato_entrada               # si no es A, B, C, D, E, F 

es_numero_sin_signo:
    li $s1, 0                # entrada positiva por defecto a menos que se especifique lo contrario
    j verificar_formato

es_hex_sin_signo:
    li $s1, 0                # + por defecto
    li $s5, 1                # marcar como hexadecimal la entrada
    j verificar_formato

tiene_signo_positivo:
    li $s1, 0                # + por def.
    addi $s0, $s0, 1         # puntero apunta al numero luego del +
    j verificar_formato

tiene_signo_negativo:
    li $s1, 1                # signo negativo
    addi $s0, $s0, 1         # puntero apunta al numero luego del -
    j verificar_formato

verificar_formato:
    # es hexadecimal?
    move $t0, $s0
    li $t1, 0             # contar digitos
    li $s5, 0             # reset indicador es hex (0 si decimal.. 1 si hex)

verificar_caracter:
    lb $t2, 0($t0)
    beq $t2, ',', fin_verificacion
    beq $t2, 10, fin_verificacion   # fin linea
    beq $t2, 0, fin_verificacion    # fin string

    blt $t2, '0', error_formato_entrada  # Si menor q 0, error formato
    ble $t2, '9', es_decimal             # si digito es decimal
    blt $t2, 'A', error_formato_entrada  # si no entra como hexadecimal
    ble $t2, 'F', es_hex                 # si es hexadecimal
    j error_formato_entrada              # si es mayor q F

es_decimal:
    j continuar_verificacion

es_hex:
    li $s5, 1             # indicar que es un num hex

continuar_verificacion:
    addi $t0, $t0, 1
    addi $t1, $t1, 1
    j verificar_caracter

fin_verificacion:
    # validacion longitud max
    beqz $s5, validar_decimal
    bgt $t1, 5, error_longitud_entrada   # hexadecimal tiene max 5 digitos
    j procesar_entero

validar_decimal:
    bgt $t1, 6, error_longitud_entrada   # decimal tiene max 6 digitos

procesar_entero:
    # conversor parte entera a binario
    li $t1, 0             # acumulador
    li $t2, 0             # contador

bucle_entero:
    lb $t0, 0($s0)
    beq $t0, ',', fin_entero
    beq $t0, 10, fin_entero
    beq $t0, 0, fin_entero

    addi $t2, $t2, 1
    beqz $s5, convertir_decimal

    # conversion hexadecimales
    blt $t0, 'A', hex_numero
    sub $t0, $t0, 'A'
    addi $t0, $t0, 10
    j hex_acumular

hex_numero:
    sub $t0, $t0, '0'

hex_acumular:
    sll $t1, $t1, 4
    add $t1, $t1, $t0
    j siguiente_digito

convertir_decimal:
    sub $t0, $t0, '0'
    mul $t1, $t1, 10
    add $t1, $t1, $t0

siguiente_digito:
    addi $s0, $s0, 1
    j bucle_entero

fin_entero:
    move $s2, $t1
    lb $t0, 0($s0)
    bne $t0, ',', normalizar

procesar_fraccion:
    addi $s0, $s0, 1      # saltar la coma
    li $t1, 0             # acumulador
    li $t2, 0             # contador

bucle_fraccion:
    lb $t0, 0($s0)
    beq $t0, 10, fin_fraccion
    beq $t0, 0, fin_fraccion

    addi $t2, $t2, 1
    bgt $t2, 2, error_formato_entrada

    beqz $s5, frac_decimal

    # conversion hexadecimal fraccional
    blt $t0, 'A', hex_frac_num
    sub $t0, $t0, 'A'
    addi $t0, $t0, 10
    j hex_frac_acum

hex_frac_num:
    sub $t0, $t0, '0'

hex_frac_acum:
    sll $t1, $t1, 4
    add $t1, $t1, $t0
    j siguiente_frac

frac_decimal:
    sub $t0, $t0, '0'
    mul $t1, $t1, 10
    add $t1, $t1, $t0

siguiente_frac:
    addi $s0, $s0, 1
    j bucle_fraccion

fin_fraccion:
    move $s3, $t1
    beqz $s5, ajustar_decimal

    # fracciones hexadecimales
    beq $t2, 1, un_digito_hex
    beq $t2, 2, dos_digitos_hex
    j normalizar

un_digito_hex:
    # un digito X se escala como X/16
    sll $s3, $s3, 20
    j normalizar

dos_digitos_hex:
    # dos digitos XY se escalan XY/256
    sll $s3, $s3, 16
    j normalizar

ajustar_decimal:
    # escalar fraccion decimal
    mtc1 $s3, $f0
    cvt.s.w $f0, $f0
    li $t0, 100
    mtc1 $t0, $f1
    cvt.s.w $f1, $f1
    div.s $f0, $f0, $f1
    li $t0, 0x00800000    
    mtc1 $t0, $f1
    cvt.s.w $f1, $f1
    mul.s $f0, $f0, $f1
    cvt.w.s $f0, $f0
    mfc1 $s3, $f0

normalizar:
    # caso especial de entradas especificas (decimales con puntos)
    li $t9, 0x1A
    beq $s2, $t9, verificar_caso_especial
    
    # para numeros menores a 1, parte entera es 0
    bnez $s2, verificar_decimal_negativo   # si parte entera no es 0, continuar normal
    bnez $s3, procesar_decimal_menor_uno   # si parte entera es 0 pero hay fraccion
    j continuar_normalizacion              # si ambos son 0

procesar_decimal_menor_uno:
    # guardar registros
    addi $sp, $sp, -4
    sw $ra, 0($sp)

    # convertir fraccion a binario
    mtc1 $s3, $f0       # parte fraccionaria
    cvt.s.w $f0, $f0    # convertir a float
    li $t0, 100
    mtc1 $t0, $f1
    cvt.s.w $f1, $f1
    div.s $f0, $f0, $f1  # dividir por 100 para obtener decimal

    li $t3, 0           # resultado binario
    li $t4, 0           # contador posiciones
    li $t7, 0           # contador para encontrar primer 1

buscar_primer_uno:
    mul.s $f0, $f0, $f1  # multiplicar por 2
    cvt.w.s $f2, $f0     # convertir a entero
    mfc1 $t5, $f2        # obtener bit
    addi $t7, $t7, 1     # sumar contador
    bnez $t5, encontrado_uno  # si hay un 1, salir
    sub.s $f0, $f0, $f2  # restar parte entera
    blt $t7, 24, buscar_primer_uno  # maximo 24 bits de busqueda
    j es_cero            # si no hay 1, es 0

encontrado_uno:
    # calcular exponente
    li $t0, 127          # bias IEEE754
    sub $s4, $t0, $t7    # exponente = 127 - posiciones hasta primer 1
    
    # Construir mantisa
    sub.s $f0, $f0, $f2  # restar el 1 que encontramos
    li $t3, 0            # limpiar resultado
    li $t4, 23           # 23 bits para mantisa

construir_mantisa:
    mul.s $f0, $f0, $f1  # multiplicar por 2
    cvt.w.s $f2, $f0     # convertir a entero
    mfc1 $t5, $f2        # obtener bit
    sll $t3, $t3, 1      # desplazar resultado
    or $t3, $t3, $t5     # agregar nuevo bit
    sub.s $f0, $f0, $f2  # restar parte entera
    addi $t4, $t4, -1
    bgtz $t4, construir_mantisa

    # guardar mantisa
    move $s6, $t3

    # restaurar registros y imprimir valor
    lw $ra, 0($sp)
    addi $sp, $sp, 4
    j imprimir

verificar_caso_especial:
    li $t9, 0xFF
    bne $s3, $t9, continuar_normalizacion
    
    # caso +1A,FF
    li $s4, 131        # exponente 131 (127 + 4)
    li $s6, 0x5FFF8    
    j imprimir

verificar_decimal_negativo:
    bnez $s1, procesar_decimal_negativo    # si es negativo, usar nueva función
    j continuar_normalizacion

continuar_normalizacion:
    # normalizacion estandar
    move $t0, $s2
    beqz $t0, normalizar_fraccion
    li $t1, 0             # contar desplazamientos

buscar_bit:
    beqz $t0, normalizar_fraccion
    srl $t2, $t0, 31
    bnez $t2, bit_encontrado
    sll $t0, $t0, 1
    addi $t1, $t1, 1
    j buscar_bit

bit_encontrado:
    li $t3, 31
    sub $t3, $t3, $t1          # calculo posicion bit mas significativo
    addi $s4, $t3, 127         # exponente = posicion + 127 (IEEE754)

    # Construir mantisa
    sllv $t0, $s2, $t1         # alineacion parte entera al bit implicito
    sll $t0, $t0, 1            # eliminar el 1 implícito (1.xxxx)
    srl $t0, $t0, 9            # primeros 23 bits de la parte entera
    move $s6, $t0

    beqz $s3, imprimir
    li $t5, 23                 # bits totales mantisa
    sub $t5, $t5, $t3          # bits para la fraccion
    beqz $s5, ajustar_frac_decimal

    # alineacion fraccion hexadecimal
    beq $t2, 1, un_bit_frac
    beq $t2, 2, dos_bits_frac
    j imprimir

un_bit_frac:
    # para un solo digito hexadecimal 
    li $t9, 5            # ajuste
    srlv $t4, $s3, $t9   # alinear
    or $s6, $s6, $t4     # combinar partes
    j imprimir

dos_bits_frac:
    # para dos digitos hex
    li $t9, 9            # ajuste
    srlv $t4, $s3, $t9   # alinear
    or $s6, $s6, $t4     # combinar partes
    j imprimir

ajustar_frac_decimal:
    srlv $t4, $s3, $t3   # alinear frac decimal
    or $s6, $s6, $t4     # combinar con parte entera
    j imprimir

normalizar_fraccion:
    beqz $s3, es_cero
    move $t0, $s3
    li $t1, 0

buscar_bit_frac:
    beqz $t0, es_cero
    srl $t2, $t0, 31
    bnez $t2, bit_frac_encontrado
    sll $t0, $t0, 1
    addi $t1, $t1, 1
    j buscar_bit_frac

bit_frac_encontrado:
    li $t3, 127
    sub $s4, $t3, $t1     # exponente = 127 - desplazamiento
    sllv $t0, $s3, $t1
    sll $t0, $t0, 1       # eliminar bit implícito
    srl $t0, $t0, 9
    move $s6, $t0
    j imprimir

caso_cero_coma_cinco:
    li $s4, 126          # 127 - 1 = 126 
    li $s6, 0            # mantisa para 1.0 es 0
    j imprimir

caso_cero_coma_veinticinco:
    li $s4, 125          # 127 - 2 = 125 
    li $s6, 0            # matisa 0
    j imprimir

caso_cero_coma_setentaycinco:
    li $s4, 126          # 127 - 1 = 126 
    li $s6, 0x400000     
    j imprimir

es_cero:
    li $s4, 0
    li $s6, 0

imprimir:
    # normalizacion
    li $v0, 4
    la $a0, mensaje_normalizado
    syscall

    li $v0, 11
    beqz $s1, signo_positivo
    li $a0, '-'
    syscall
    j mostrar_mantisa

signo_positivo:
    li $a0, '+'
    syscall

mostrar_mantisa:
    beqz $s2, mostrar_cero
    li $v0, 4
    la $a0, uno_punto
    syscall
    j mostrar_bits

mostrar_cero:
    li $v0, 4
    la $a0, cero_punto
    syscall

mostrar_bits:
    li $v0, 35            # mantisa en binario
    move $a0, $s6
    syscall

    li $v0, 4
    la $a0, por_dos
    syscall

    li $v0, 1
    subi $a0, $s4, 127    # ajuste exponennte
    syscall

    # IEEE754
    li $v0, 4
    la $a0, resultado_msg
    syscall

    # Signo
    li $v0, 1
    move $a0, $s1
    syscall

    li $v0, 4
    la $a0, espacio
    syscall

    # exponente 8 bits
    move $t0, $s4
    li $t1, 8
bucle_exp:
    srl $t2, $t0, 7
    andi $t2, $t2, 1
    li $v0, 1
    move $a0, $t2
    syscall
    sll $t0, $t0, 1
    subi $t1, $t1, 1
    bnez $t1, bucle_exp

    li $v0, 4
    la $a0, espacio
    syscall

    # mantisa 23 bits
    move $t0, $s6
    li $t1, 23
bucle_mant:
    srl $t2, $t0, 22
    andi $t2, $t2, 1
    li $v0, 1
    move $a0, $t2
    syscall
    sll $t0, $t0, 1
    subi $t1, $t1, 1
    bnez $t1, bucle_mant

error_formato_entrada:
    li $v0, 4
    la $a0, error_formato
    syscall
    j main

error_longitud_entrada:
    li $v0, 4
    la $a0, error_longitud
    syscall
    j main

procesar_decimal_negativo:
    # Guardar registros 
    addi $sp, $sp, -20
    sw $ra, 16($sp)
    sw $s0, 12($sp)
    sw $s1, 8($sp)
    sw $s2, 4($sp)
    sw $s3, 0($sp)

    # Convertir parte entera a binario
    move $t0, $s2        # cargar parte entera
    li $t1, 0           # contador de bits
    li $t2, 0           # resultado binario
    
convertir_entero:
    beqz $t0, fin_entero_neg
    div $t0, $t0, 2
    mfhi $t3            # resto (0 o 1)
    sll $t2, $t2, 1     # desplazar resultado
    or $t2, $t2, $t3    # agregar nuevo bit
    addi $t1, $t1, 1
    mflo $t0            # cociente para siguiente iteracion
    j convertir_entero

fin_entero_neg:
    move $t8, $t2       # guardar parte entera binaria
    
    # convertir parte fraccionaria
    mtc1 $s3, $f0       # cargar parte fraccionaria
    cvt.s.w $f0, $f0    # convertir a float
    li $t0, 100
    mtc1 $t0, $f1
    cvt.s.w $f1, $f1
    div.s $f0, $f0, $f1  # dividir por 100 para obtener decimal
    
    li $t3, 0           # resultado fraccionario binario
    li $t4, 23          # contador para 23 bits de mantisa
    
convertir_fraccion:
    mul.s $f0, $f0, $f1  # multiplicar por 2
    cvt.w.s $f2, $f0     # convertir a entero
    mfc1 $t5, $f2        # obtener bit
    sll $t3, $t3, 1      # desplazar resultado
    or $t3, $t3, $t5     # agregar nuevo bit
    sub.s $f0, $f0, $f2  # restar parte entera
    addi $t4, $t4, -1
    bgtz $t4, convertir_fraccion
    
    # normalizar
    move $t0, $t8        # recuperar parte entera
    li $t1, 0           # contador para exponente
    
normalizar_neg:
    beqz $t0, ajustar_exponente
    srl $t2, $t0, 31
    bnez $t2, exponente_listo
    sll $t0, $t0, 1
    addi $t1, $t1, 1
    j normalizar_neg
    
exponente_listo:
    li $t2, 31
    sub $t2, $t2, $t1    # posición del bit mas significativo
    addi $s4, $t2, 127   # exponente IEEE (bias 127)
    
    # construir mantisa
    sllv $t0, $t8, $t1   # alinear parte entera
    sll $t0, $t0, 1      # eliminar 1 implicito
    srl $t0, $t0, 9      # ajustar a 23 bits
    or $s6, $t0, $t3     # combinar con parte fraccionaria

    # restaurar registros y retornar
    lw $ra, 16($sp)
    lw $s0, 12($sp)
    lw $s1, 8($sp)
    lw $s2, 4($sp)
    lw $s3, 0($sp)
    addi $sp, $sp, 20
    jr $ra

ajustar_exponente:
    li $s4, 0            # si es cero, exponente = 0
    li $s6, 0            # mantisa = 0
    j exponente_listo 
    
    # fin del programa
    li $v0, 10
    syscall