	\\ LOADROM
	\\ 27 SEPT 2013 (REVISED 21 JUNE 2016)
	\\ BY MARTIN MATHER

	ROMNO=6				; Target ROM

	romsel=&FE30
	romselcopy=&F4

	addr1=&70
	addr2=&72
	currentrom=&74
	count=&78

	ORG &1900

.start
	\ BASIC:
	\ 10CALLPAGE+16
	\ 20END
	EQUB &0D, &00, &0A, &09, &D6, &90, &2B, &31
	EQUB &36, &0D, &00, &14, &05, &E0, &0D, &FF

	\ Get address of romcode

	LDA #&60			; RTS
	STA &100
	JSR &100			; XY=address l2-1

.l2	SEC	
	TSX
	DEX
	LDA &100,X
	ADC #LO(romcode-l2)
	STA addr1
	STA addr2
	LDA &101,X
	ADC #HI(romcode-l2)
	STA addr1+1
	STA addr2+1

	LDA #LO(((codeend-romcode) EOR &FFFF)+1)
	STA count
	LDA #HI(((codeend-romcode) EOR &FFFF)+1)
	STA count+1	

	LDA romselcopy
	STA currentrom

	LDX #ROMNO

	\ Check it's sideways RAM

.rl1	STX romsel
	LDA &8FFF
	PHA
	EOR #&FF
	STA &8FFF
	PLA
	PHA
	ORA &8FFF
	STA count
	PLA
	STA &8FFF
	INC count
	BEQ rl3

	\ Not RAM!

.rl2	LDA currentrom
	STA romselcopy
	STA romsel
	BRK
	EQUS "*RAM?"
	BRK

	\ copy rom to sideways RAM

.rl3	LDY #0
	LDA #&80
	STY addr1
	STA addr1+1
	LDX #16*4			; Number of pages

.rl4	LDA (addr2),Y
	STA (addr1),Y
	INY
	BNE rl4

	INC addr1+1
	INC addr2+1
	DEX
	BNE rl4

	LDA currentrom
	STA romselcopy
	STA romsel
	RTS

.romcode

	INCBIN "U120UP.ROM"

.codeend

	SAVE "UROM", start, codeend, start, start

\ EOF