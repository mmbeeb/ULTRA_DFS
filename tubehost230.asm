	\\ Acorn Tube Host 2.30
	\\ tubehost230.asm
	\\ Compiler: BeebAsm V1.08
	\\ Disassembly by Martin Mather

	\\ ****** TUBE HOST 2.30 ******

.TUBE_CODE_500
{
	EQUB  &37, &05, &96, &05, &F2, &05, &07, &06
	EQUB  &27, &06, &68, &06, &5E, &05, &2D, &05
	EQUB  &20, &05, &42, &05, &A9, &05, &D1, &05
	EQUB  &86, &88, &96, &98, &18, &18, &82, &18

.tube520
	JSR &06C5
	TAY 
	JSR &06C5
	JSR OSBPUT
	JMP &059C

	JSR &06C5
	TAY 
	JSR OSBGET
	JMP &053A

	JSR OSRDCH
	ROR A
	JSR &0695
	ROL A
	JMP &059E

	JSR &06C5
	BEQ Label_AD2D

	PHA 
	JSR &0582
	PLA 
	JSR OSFIND
	JMP &059E

.Label_AD2D
	JSR &06C5
	TAY 
	LDA #&00
	JSR OSFIND
	JMP &059C

	JSR &06C5
	TAY 
	LDX #&04

.Label_AD3F
	JSR &06C5
	STA &FF,X
	DEX 
	BNE Label_AD3F

	JSR &06C5
	JSR OSARGS
	JSR &0695
	LDX #&03

.Label_AD52
	LDA &00,X
	JSR &0695
	DEX 
	BPL Label_AD52

	JMP &0036

	LDX #&00
	LDY #&00

.Label_AD61
	JSR &06C5
	STA &0700,Y
	INY 
	BEQ Label_AD6E

	CMP #&0D
	BNE Label_AD61

.Label_AD6E
	LDY #&07
	RTS 

	JSR &0582
	JSR OSCLI
	LDA #&7F

.Label_AD79
	BIT TUBE_R2_STATUS
	BVC Label_AD79

	STA TUBE_R2_DATA

.Label_AD81
	JMP &0036

	LDX #&10

.Label_AD86
	JSR &06C5
	STA &01,X
	DEX 
	BNE Label_AD86

	JSR &0582
	STX &00
	STY &01
	LDY #&00
	JSR &06C5
	JSR OSFILE
	JSR &0695
	LDX #&10

.Label_ADA2
	LDA &01,X
	JSR &0695
	DEX 
	BNE Label_ADA2
	BEQ Label_AD81

	LDX #&0D

.Label_ADAE
	JSR &06C5
	STA &FF,X
	DEX 
	BNE Label_ADAE

	JSR &06C5
	LDY #&00
	JSR OSGBPB
	PHA 
	LDX #&0C

.Label_ADC1
	LDA &00,X
	JSR &0695
	DEX 
	BPL Label_ADC1

	PLA 
	JMP &053A

	JSR &06C5
	TAX 
	JSR &06C5
	JSR OSBYTE

.Label_ADD7
	BIT TUBE_R2_STATUS
	BVC Label_ADD7

	STX TUBE_R2_DATA

.Label_ADDF
	JMP &0036

	JSR &06C5
	TAX 
	JSR &06C5
	TAY 
	JSR &06C5
	JSR OSBYTE
	EOR #&9D
	BEQ Label_ADDF

	ROR A
	JSR &0695

.Label_ADF8
	BIT TUBE_R2_STATUS
	BVC Label_ADF8

	STY TUBE_R2_DATA
	BVS Label_ADD7

	JSR &06C5
	TAY 

.Label_AE06
	BIT TUBE_R2_STATUS
	BPL Label_AE06

	LDX TUBE_R2_DATA
	DEX 
	BMI Label_AE20

.Label_AE11
	BIT TUBE_R2_STATUS
	BPL Label_AE11

	LDA TUBE_R2_DATA
	STA &0128,X
	DEX 
	BPL Label_AE11

	TYA 

.Label_AE20
	LDX #&28
	LDY #&01
	JSR OSWORD

.Label_AE27
	BIT TUBE_R2_STATUS
	BPL Label_AE27

	LDX TUBE_R2_DATA
	DEX 
	BMI Label_AE40

.Label_AE32
	LDY &0128,X

.Label_AE35
	BIT TUBE_R2_STATUS
	BVC Label_AE35

	STY TUBE_R2_DATA
	DEX 
	BPL Label_AE32

.Label_AE40
	JMP &0036

	LDX #&04

.Label_AE45
	JSR &06C5
	STA &00,X
	DEX 
	BPL Label_AE45

	INX 
	LDY #&00
	TXA 
	JSR OSWORD
	BCC Label_AE5B

	LDA #&FF
	JMP &059E

.Label_AE5B
	LDX #&00
	LDA #&7F
	JSR &0695

.Label_AE62
	LDA &0700,X
	JSR &0695
	INX 
	CMP #&0D
	BNE Label_AE62

	JMP &0036

.Label_AE70
	BIT TUBE_R2_STATUS
	BVC Label_AE70

	STA TUBE_R2_DATA
	RTS 

.Label_AE79
	BIT TUBE_R4_STATUS
	BVC Label_AE79

	STA TUBE_R4_DATA
	RTS 

	LDA &FF
	SEC 
	ROR A
	BMI Label_AE97

	PHA 
	LDA #&00
	JSR &06BC
	TYA 
	JSR &06BC
	TXA 
	JSR &06BC
	PLA 

.Label_AE97
	BIT TUBE_R1_STATUS
	BVC Label_AE97

	STA TUBE_R1_DATA
	RTS 

.Label_AEA0
	BIT TUBE_R2_STATUS
	BPL Label_AEA0

	LDA TUBE_R2_DATA
	RTS
}

.SERVICE09_TUBEHelp
{
	CMP #&09			;*HELP
	BNE SERVICEFE_TUBEPostInit

	TYA 
	PHA 
	LDA (TextPointer),Y
	CMP #&0D
	BNE Label_AED3

	LDA #&E9
	JSR osbyteX00YFF
	LDX PagedRomSelector_RAMCopy
	TYA 
	BEQ Label_AED3

	JSR PrtString
	EQUS 13, "TUBE HOST 2.30", 13
	NOP 

.Label_AED3
	PLA 
	TAY 
	LDA #&09

.SERVICEFE_TUBEPostInit
	CMP #&FE			;TUBE post initialisation
	BCC servFE_exit
	BNE SERVICEFF_TUBEInit

	CPY #&00
	BEQ servFE_exit

	LDX #&06
	LDA #&14
	JSR OSBYTE			;Enable ESCAPE pressed event

.servFE_tubemsg_loop
	BIT TUBE_R1_STATUS		;Print TUBE start up message
	BPL servFE_tubemsg_loop

	LDA TUBE_R1_DATA
	BEQ servFE_exitA_0

	JSR OSWRCH
	JMP servFE_tubemsg_loop

.SERVICEFF_TUBEInit
	LDA #&AD			;TUBE main initialisation
	STA &0220
	LDA #&06
	STA &0221			;EVNTV=06AD
	LDA #&16
	STA &0202
	LDA #&00
	STA &0203			;BRKV=&0016
	LDA #&8E
	STA TUBE_R1_STATUS
	LDY #&00			;COPY TUBE CODE TO &400

.servFF_copytubecode_loop
	LDA TUBE_CODE_400,Y
	STA &0400,Y
	LDA TUBE_CODE_500,Y
	STA &0500,Y
	LDA TUBE_CODE_500+&100,Y
	STA &0600,Y
	DEY 
	BNE servFF_copytubecode_loop

	JSR &0421			;CALL TUBE CODE
	LDX #&41			;Copy error handling code

.servFF_copytubezpcode_loop
	LDA TUBE_ZP_CODE_0016,X
	STA &16,X
	DEX 
	BPL servFF_copytubezpcode_loop

.servFE_exitA_0
	LDA #&00

.servFE_exit
	RTS
}

.TUBE_ZP_CODE_0016
{
	LDA #&FF			;COPIED TO &0016
	JSR &069E
	LDA TUBE_R2_DATA
	LDA #&00
	JSR &0695
	TAY 
	LDA (&FD),Y
	JSR &0695

.Label_AF4B
	INY 
	LDA (&FD),Y
	JSR &0695
	TAX 
	BNE Label_AF4B

	LDX #&FF
	TXS 
	CLI 

.Label_AF58
	BIT TUBE_R1_STATUS
	BPL Label_AF63

.Label_AF5D
	LDA TUBE_R1_DATA
	JSR OSWRCH

.Label_AF63
	BIT TUBE_R2_STATUS
	BPL Label_AF58

	BIT TUBE_R1_STATUS
	BMI Label_AF5D

	LDX TUBE_R2_DATA
	STX &51
	JMP (&0500)

	EQUB  &00, &80, &00, &00
}

.TUBE_CODE_400
{
	JMP &0484			;COPIED TO &0400-&04FF

	JMP &06A7

	CMP #&80
	BCC Label_AFAE

	CMP #&C0
	BCS Label_AFA1

	ORA #&40
	CMP &15
	BNE Label_AFAD

	PHP 
	SEI 
	LDA #&05
	JSR &069E
	LDA &15
	JSR &069E
	PLP 
	LDA #&80
	STA &15
	STA &14
	RTS 

.Label_AFA1
	ASL &14
	BCS Label_AFAB

	CMP &15
	BEQ Label_AFAD

	CLC 
	RTS 

.Label_AFAB
	STA &15

.Label_AFAD
	RTS 

.Label_AFAE
	PHP 
	SEI 
	STY &13
	STX &12
	JSR &069E
	TAX 
	LDY #&03
	LDA &15
	JSR &069E

.Label_AFBF
	LDA (&12),Y
	JSR &069E
	DEY 
	BPL Label_AFBF

	LDY #&18
	STY TUBE_R1_STATUS
	LDA &0518,X
	STA TUBE_R1_STATUS
	LSR A
	LSR A
	BCC Label_AFDC

	BIT TUBE_R3_DATA
	BIT TUBE_R3_DATA

.Label_AFDC
	JSR &069E

.Label_AFDF
	BIT TUBE_R4_STATUS
	BVC Label_AFDF
	BCS Label_AFF3

	CPX #&04
	BNE Label_AFFB

.Label_AFEA
	JSR &0414
	JSR &0695
	JMP &0032

.Label_AFF3
	LSR A
	BCC Label_AFFB

	LDY #&88
	STY TUBE_R1_STATUS

.Label_AFFB
	PLP 
	RTS 

	CLI 
	BCS Label_B00A
	BNE Label_B005

	JMP &059C

.Label_B005
	LDX &028D
	BEQ Label_AFEA

.Label_B00A
	LDA #&FF
	JSR TubeCode
	BCC Label_B00A

	JSR &04CE

.Label_B014
	PHP 
	SEI 
	LDA #&07
	JSR &04C7
	LDY #&00
	STY &00

.Label_B01F
	LDA (&00),Y
	STA TUBE_R3_DATA
	NOP 
	NOP 
	NOP 
	INY 
	BNE Label_B01F

	PLP 
	INC &54
	BNE Label_B035

	INC &55
	BNE Label_B035

	INC &56

.Label_B035
	INC &01
	BIT &01
	BVC Label_B014

	JSR &04CE
	LDA #&04
	LDY #&00
	LDX #&53
	JMP TubeCode

	LDA #&80
	STA &54
	STA &01
	LDA #&20
	AND romtype
	TAY 
	STY &53
	BEQ Label_B070

	LDX copywoffset

.Label_B05A
	INX 
	LDA &8000,X
	BNE Label_B05A

	LDA &8001,X
	STA &53
	LDA &8002,X
	STA &54
	LDY &8003,X
	LDA &8004,X

.Label_B070
	STA &56
	STY &55
	RTS 				;END OF TUBE CODE PAGE &400
}

; END OF TUBE HOST CODE
