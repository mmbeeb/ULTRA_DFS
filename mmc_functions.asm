	\-------------------------------------------------------------------\
	\ Title   : Ultra DFS                                               \
	\ Author  : Martin Mather 2015                                      \
	\ Compiler: BeebAsm V1.08                                           \
	\-------------------------------------------------------------------\
	\ Module  : mmc_functions.asm                                       \
	\-------------------------------------------------------------------\

	\*/ VID (Very Import Data) routines.

	\\ If these bytes get corrupted and we don't know about it,
	\\ it could lead to data on the MMC/SD card also becoming corrupted,
	\\ e.g. the wrong sector could be written to.
	\\ For this reason it is protected by a CRC.

	\ Reset the VID.
.VID_do_reset
{
	LDY #VID_SIZE-1
	LDA #0

.loop	STA VID,Y
	DEY
	BPL loop

	INC VID_CRC			;CRC7 = 1
	RTS
}

	\ Calculate and test VID CRC (CRC7).
	\ On exit: A=CRC7, X=0, Y=FF, Z=CRC correct.
.VID_calc_crc
{
	LDY #VID_SIZE-2
	LDA #0

.loop1	EOR VID,Y
	ASL A
	LDX #7

.loop2	BCC b7z1

	EOR #&12

.b7z1	ASL A
	DEX
	BNE loop2
	BCC b7z2

	EOR #&12

.b7z2	DEY
	BPL loop1

	ORA #&01
	CMP VID_CRC
	RTS
}

	\ Check the VID CRC, and if wrong report error.
	\ On exit: If no error, all registers preserved.
.VID_check_report
{
	JSR rememberAXY
	JSR VID_calc_crc
	BNE errBadCRC

	RTS

.errBadCRC
	JSR errBAD
	EQUB &FF
	EQUS "CRC",0
}

	\ Reset the VID CRC (i.e. after VID written to).
	\ On exit: All registers preserved.
.VID_reset_crc
	JSR rememberAXY
	JSR VID_calc_crc
	STA VID_CRC
	RTS


	\*/ Keyboard LEDs.

	\ Illuminate Caps Lock & Shift Lock LEDs to signify MMC busy.
	\ (No OS call to do this without changing keyboard state.)
.LEDS_set
	LDX #&6
	STX SYSVIA
	INX
	STX SYSVIA
	RTS

	\ Reset LEDs to reflect keyboard state.
	\ On exit: All registers preserved.
.LEDS_reset
	JSR rememberAXY
	LDA #&76
	JMP OSBYTE


	\*/ MMC card error reporting.

	\ Entry: A = MMC response.
	\ Error string termintated with value=&00 or value>=&80.
	\ If latter then print command parameter (e.g. sector).
.mmc_report_error
{
	response = &B3
	ptr = &AE

	STA response

	PLA				;Address of string.
	STA ptr
	PLA
	STA ptr+1

	JSR LEDS_reset

	LDY #&FF
	STY LoadedCatDrive		;Make catalogue invalid.

	INY				;Y=0
	STY MMC_STATE

.loop	INY				;Copy error string.
	LDA (ptr),Y
	STA &100,Y
	BMI exit
	BNE loop

.exit	PHP

	TYA				;X=Y
	TAX

	LDA response
	JSR prthex_100_X		;Print MMC response.

	PLP
	BPL j100			;If string terminated with &00.

	LDA #'/'			;Print MMC command parameter.
	STA &100,X
	INX

;	LDA par%
	JSR prthex_100_X
;	LDA par%+1
	JSR prthex_100_X
;	LDA par%+2
	JSR prthex_100_X

.j100	LDA #0				;Terminate string.
	STA &100
	STA &100,X
	JMP &100
}

	\*/ Command line interpreter functions.


	\ **** Read decimal number at TxtPtr+Y ****
	\ on exit;
	\ if valid (0 - 510);
	\ C=0, AX=number, &
	\ Y points to next chr
	\ if not valid;
	\ C=1, AX=0, &
	\ Y=entry value
	\ Exit: Uses memory &B0 + &B1

	rn%=&B0

.Param_ReadNum
{
	TYA
	PHA				;\ 1

	LDA #0
	STA rn%
	STA rn%+1

	JSR GSINIT_A
	BEQ notval			;If null string

	CMP #&22
	BEQ notval

	JSR GSREAD
	BCS notval			;Should never happen!

.loop	SEC
	SBC #48
	BMI notval

	CMP #10
	BCS notval

	\\ N=N*2+N*8+A
	PHA				;\ 2
	LDA rn%
	ASL A
	PHA				;\ 3
	ROL rn%+1
	LDX rn%+1
	ASL A
	ROL rn%+1
	ASL A
	ROL rn%+1
	STA rn%
	PLA				;\ 3
	ADC rn%
	STA rn%
	TXA
	ADC rn%+1
	TAX
	PLA				;\ 2
	ADC rn%
	STA rn%
	TXA
	ADC #0
	STA rn%+1
	CMP #2
	BCS notval

	JSR GSREAD
	BCC loop

	\\ <>511?
.exit	LDX rn%
	LDA rn%+1
	BEQ ok

	INX
	BEQ notval

	DEX

.ok	PLA 				;\ 1 - ignore Y
	LDA rn%+1
	CLC
	RTS

	\ Not a valid number, restore Y and set C
.notval	PLA				;\ 1
	TAY 				;restore Y

	LDA #0
	TAX
	SEC
	RTS
}

	\ Read parameters : drive optional
	\ (<drive>) <dno>/<dsp>
	\ Exit: CurrentDrv = drive
	\       Word &B8   = disk no.
.Param_DriveAndDisk
{
	JSR Param_SyntaxErrorIfNull

	CMP #&22
	BNE param_nq1

	DEY

.param_nq1
	STY &B4				;Save Y

	JSR GSREAD_A
	CMP #':'			;ASC(":")
	BNE param_dad

	JSR Param_DriveNo_BadDrive
	BCC Param_Disk			;always

.param_dad
	LDY &B4				;Restore Y
	JSR Set_CurDrv_ToDefault

	\ Read 1st number
	JSR Param_ReadNum		;rn% @ B0
	BCS gddfind			;if not valid number

	JSR GSINIT_A
	BEQ gdnodrv			;if rest of line blank

	CMP #&22
	BNE param_nq2

	DEY

.param_nq2
	LDA rn%+1
	BNE errBADDRIVE2		;AX>255

	LDA rn%
	CMP #4
	BCS errBADDRIVE2

	JSR SetCurrentDriveA_nowait

	\JMP Param_Disk
}


	\ Read (2nd) number?
	\ If it's not a valid number:
	\ assume it's a disk name
	\ <dno>/<dsp>
	\ Exit: Word &B8 = disk no.
.Param_Disk
	JSR Param_ReadNum		;rn% @ B0
	BCS gddfind			;if not valid number

	JSR GSINIT_A
	BNE errSYNTAX2			;if rest of line not blank

.gdnodrv
	LDA rn%+1
	STA &B9
	LDA rn%
	STA &B8

.gddfound
	RTS


.errBADDRIVE2
	JMP errBADDRIVE			;Bad drive!

.errSYNTAX2
	JMP errSYNTAX			;Syntax!

.errDISKNOTFOUND
	JSR errDISK			;Disk not found!
	EQUB 214
	EQUS "not found", 0


	\ The parameter is not valid number;
	\ so it must be a disk name?!

	gdptr%=&B0
	gdsec%=&B2
	gddiskno%=&B8
	gdopt%=&B7

.gddfind
{
	jmp errSYNTAX2

	;;JSR DMatchInit

	LDA #0
	STA gdopt%			;Don't return unformatted disks.

;	JSR GetDiskFirstAll

;	LDA dmLen%
	BEQ errSYNTAX2

;	LDA dmAmbig%
	BNE errSYNTAX2

.loop	LDA gddiskno%+1
	BMI errDISKNOTFOUND

	;JSR DMatch
	BCC gddfound

	;JSR GetDiskNext
	JMP loop
}


	\*/ Screen output.

	\ Convert 9 bit binary in word &B8 to
	\ 3 digit BCD in word &B5 (decno%).

	decno%=&B5

	\ Used by GetDisk.
.DecNo_BIN2BCD
{
	LDX &B8
	LDY #0
	STY decno%+1

.loop	TXA
	CMP #10
	BCC exloop

	SBC #10
	TAX
	SED
	CLC
	TYA
	ADC #&10
	TAY
	CLD
	BCC loop

	INC decno%+1
	BCS loop

.exloop	SED
	STY decno%
	ADC decno%
	TAY
	BCC noinc

	INC decno%+1
	CLC

.noinc	LDX &B9 			;>&FF ?
	BEQ noadd

	ADC #&56
	TAY
	LDA decno%+1
	ADC #&02
	STA decno%+1

.noadd	CLD
	STY decno%
	RTS
}



\\//\\// End of file \\//\\//
