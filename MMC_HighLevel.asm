\** MMFS ROM by Martin Mather
\** Compiled using BeebAsm V1.04
\** August 2011

\\ ******* HIGH LEVEL MMC CODE ********

;go_idle_state=&40
;send_op_cond=&41
;send_cid=&4A
;set_blklen=&50
;read_single_block=&51
;write_block=&58


	\\ **** Reset MMC Command Sequence ****
	\\ A=cmd, token=&FF
.MMC_SetCommand
{
	STA cmdseq%+1

	LDA #0
	STA cmdseq%+2
	STA cmdseq%+3
	STA cmdseq%+4
	STA cmdseq%+5

	LDA #&FF
	STA cmdseq%
	STA cmdseq%+6			;\ token
	STA cmdseq%+7
	RTS
}


	\\ ***** Initialise MMC card *****
	\\ Carry=0 if ok
	\\ Carry=1 if card doesn't repsond at all!

.MMC_INIT
{
	trys%=&32
	attempts%=&C2

	JSR LEDS_set

	LDA #0
	STA MMC_STATE

	LDA #trys%
	STA attempts%

	\\ 80 Clocks

.iloop	LDY #10
	JSR MMC_Clocks

	\\ CMD0

	LDA #go_idle_state
	JSR MMC_SetCommand
	LDA #&95
	STA cmdseq%+6			; token (crc7)
	JSR MMC_DoCommand
	AND #&81			; ignore errors
	CMP #1
	BNE ifail

	\\ CMD1

	LDA #send_op_cond
	JSR MMC_SetCommand

.il1	BIT EscapeFlag			; may hang
	BMI ifail

	JSR MMC_DoCommand
	CMP #2
	BCS ifail			; error occurred?

	CMP #0
	BNE il1

	\\ Set blklen=512

.iok	LDA #set_blklen
	JSR MMC_SetCommand
	LDA #2
	STA par%+2
	JSR MMC_DoCommand
	BNE blkerr

	\\ All OK!

	LDA #&40
	STA MMC_STATE
	JSR LEDS_reset
	CLC
	RTS

	\\ Try again?

.ifail	DEC attempts%
	BNE iloop

	\\ Give up!

	JSR LEDS_reset
	SEC
	RTS

	\\ Failed to set block length

.blkerr	JSR MMC_ReportErrS
	EQUB &FF
	EQUS "Set block len error ",0
}


	\\ Read CID and return CRC16 in YA
.MMC_GetCIDCRC
	LDA #send_cid
	JSR MMC_SetCommand
	JSR MMC_StartRead
	LDY #16
	JSR MMC_Clocks
	JSR MMC_GetByte
	TAY
	JMP MMC_GetByte


	\ **** Set-up MMC command sequence ****
.MMC_SetupWrite
	LDA #write_block
	BNE setuprw


.MMC_SetupRead
	LDA #read_single_block

.setuprw
	JSR MMC_SetCommand
	LDA sec%			; Copy sec% to par%
	STA par%+2
	LDA sec%+1
	STA par%+1
	LDA sec%+2
	STA par%
	RTS


	\ **** Begin Read Transaction ****
.MMC_StartRead
	JSR MMC_DoCommand
	BNE errRead

	JMP MMC_WaitForData

.errRead
	JSR MMC_ReportErrS
	EQUB &C5
	EQUS "MMC Read fault ",0


	\ **** Begin Write Transaction ****
.MMC_StartWrite
	JSR MMC_DoCommand
	BNE errWrite

	JMP MMC_SendingData


.errWrite
	JSR MMC_ReportErrS
	EQUB &C5
	EQUS "MMC Write fault ",0

	\\ **** Read 2 sectors to "Catalogue" ****
	\\ i.e. pages &E and &F
	\\ (Start sector must be even)
.SetupCatRW
	JSR LEDS_set
	LDA #0
	STA TubeNoTransferIf0
	STA datptr%
	LDA #MP+&0E
	STA datptr%+1
	RTS


	\\ **** Read the Catalogue ****
.MMC_ReadCatalogue
	JSR SetupCatRW
	JSR MMC_SetupRead
	JSR MMC_StartRead
	JSR MMC_Read256
	INC datptr%+1
	JSR MMC_Read256
	JSR MMC_16Clocks		; ignore CRC
	JMP LEDS_reset


	\\ **** Write the Catalgoue ****
.MMC_WriteCatalogue
	JSR SetupCatRW
	JSR MMC_SetupWrite
	JSR MMC_StartWrite
	JSR MMC_Write256
	INC datptr%+1
	JSR MMC_Write256
	JSR MMC_EndWrite
	JMP LEDS_reset


	\\ **** Check if data to/from Tube ****
	\\ Set transfer up if yes.  Exit C=0=Tube Xfr
.MMC_RWBlock_CheckIfToTube
{
	PHA				; 0=read / 1=write

	\ Copy load address to 1072
	LDA MMC_WSP+0
	STA MA+&1072
	LDA MMC_WSP+1
	STA MA+&1073

	LDA MA+&1074
	AND MA+&1075
	ORA TubePresentIf0
	EOR #&FF
	STA TubeNoTransferIf0

	SEC
	BEQ notTube

	JSR TUBE_CLAIM

	LDX #&72			; tell SP
	LDY #MP+&10
	PLA
	PHA
	JSR TubeCode			; YX=addr,A=0:initrd,A=1:initwr,A=4:strexe
	CLC

.notTube
	PLA
	RTS
}


	\\ **** Read data block to memory ****
	\\ at loc. datptr%
	\\ sec%, seccount% & byteslastsec%
	\\ define block
.MMC_ReadBlock
{
	JSR LEDS_set
	JSR rdblk
	JMP LEDS_reset

.rb1_exit
	RTS

.rdblk	LDX seccount%
	BEQ rb1_exit			; nothing to do

	LDA #1
	JSR MMC_RWBlock_CheckIfToTube

	LDX seccount%
	ROR sec%
	ROR skipsec%
	BPL rb2
	INX

.rb2	STX seccount%
	ASL sec%			; sec always even

	JSR MMC_SetupRead

	LDX seccount%
	CPX #3
	BCS rb3				; X>2 = more than 2 sectors

.rb4_loop
	LDA byteslastsec%
	BNE rb5				; don't read whole sector
	CPX #1
	BEQ rb9				; one sector left

.rb3	BIT skipsec%
	BPL rb6_loop

	\\ read odd sector
	JSR MMC_StartRead
	LDY #0
	STY skipsec%
	JSR MMC_Clocks
	JMP rb7

	\\ read even sectors
.rb6_loop
	JSR MMC_StartRead
	JSR MMC_Read256
	INC datptr%+1

.rb7	JSR MMC_Read256
	INC datptr%+1
	JSR MMC_16Clocks		; ignore CRC

	\\ increment MMC sector
	INC par%+2			; sec always even
	INC par%+2
	BNE rb8
	INC par%+1
	BNE rb8
	INC par%

.rb8	LDX seccount%			; X>=2
	DEX
	DEX
	BEQ rb1_exit

	STX seccount%
	CPX #3
	BCS rb6_loop
	JMP rb4_loop


.rb9	JSR MMC_StartRead
	JSR MMC_Read256
	JMP rbx4

	\\ A=byteslastsec>0

.rb5	JSR MMC_StartRead

	BIT skipsec%
	BPL rbx1

	LDY #0				; Skip first MMC sector
	JSR MMC_Clocks
	JMP rbx2

.rbx1	DEC seccount%			; =1 or =2
	BEQ rbx2

	JSR MMC_Read256
	INC datptr%+1

.rbx2	JSR MMC_ReadBLS
	TYA				; BLS
	EOR #&FF
	TAY
	INY
	JSR MMC_Clocks

	LDA seccount%
	BNE rbx3

.rbx4	LDY #0
	JSR MMC_Clocks

.rbx3	JMP MMC_16Clocks
}

	\\ **** Write data block from memory ****
.wb1
	RTS


.MMC_WriteBlock
{
	JSR LEDS_set
	JSR wrblk
	JMP LEDS_reset

.wrblk	LDX seccount%
	BEQ wb1				; nothing to do!

	LDA #0
	JSR MMC_RWBlock_CheckIfToTube

	LDX seccount%
	ROR sec%
	ROR A
	ASL sec%
	PHA

	JSR MMC_SetupWrite

	PLA
	BPL wb2				; sec even!

	\\ start is odd!
	\\ read mmc sector bytes 0-255
	\\ to buffer, then rewrite it
	\\ with page 1 of the data

	LDA #read_single_block
	STA cmdseq%+1
	JSR MMC_StartRead
	JSR MMC_ReadBuffer
	LDY #0
	JSR MMC_Clocks
	LDY #2
	JSR MMC_Clocks

	LDA #write_block
	STA cmdseq%+1
	JSR MMC_StartWrite
	JSR MMC_WriteBuffer
	JSR MMC_Write256
	JSR MMC_EndWrite
	DEC seccount%
	BEQ wb1				; finished
	INC datptr%+1

	\\ sector+=2

.wb4	INC par%+2
	INC par%+2
	BNE wb2
	INC par%+1
	BNE wb2
	INC par%

.wb2	LDX seccount%
	BEQ wb5				; finished

	DEX
	BNE wb3				; seccount>=2

	\\ 1 sector left
	\\ read mmc sector bytes 256-511
	\\ to buffer, then write last
	\\ page of data, followed by the
	\\ data in the buffer

	LDA #read_single_block
	STA cmdseq%+1
	JSR MMC_StartRead
	LDY #0
	JSR MMC_Clocks
	JSR MMC_ReadBuffer
	LDY #2
	JSR MMC_Clocks

	LDA #write_block
	STA cmdseq%+1
	JSR MMC_StartWrite
	JSR MMC_Write256
	JSR MMC_WriteBuffer
	JMP MMC_EndWrite		; finished

	\\ write whole sectors
	\\ i.e. 2 pages (512 bytes)

.wb3	JSR MMC_StartWrite
	JSR MMC_Write256
	INC datptr%+1
	JSR MMC_Write256
	INC datptr%+1
	JSR MMC_EndWrite
	DEC seccount%
	DEC seccount%
	BNE wb4

.wb5	RTS
}


	\\ **** CHECK MMC STATUS ****
	\\ Preserves AXY, and values in BC-C5
.MMC_BEGIN2
	JSR RememberAXY
	JSR MMC_BEGIN1
	JMP MMC_END


	\\ **** BEGIN MMC TRANSACTION ****
	\\ Save values in BC-C5 at 10B0-10B9
.MMC_BEGIN1
{
{
	LDX #9

.begloop1
	LDA &BC,X
	STA MMC_WSP,X
	DEX
	BPL begloop1

	\\ Reset device
	JSR MMC_DEVICE_RESET

	\\ Check if MMC initialised
	\\ If not intialise the card
	BIT MMC_STATE
	BVS beg2

	JSR MMC_INIT
	BCS carderr

	JSR MMC_CheckCardID

	\\ Check MMC_SECTOR & DRIVE_INDEX initialised

.beg2	JSR VID_check_report

	LDA MMC_SECTOR
	ORA MMC_SECTOR+1
	ORA MMC_SECTOR+2
	BEQ beg3

	RTS

.beg3	JSR MMC_Sector_Reset
	JMP MMC_LoadDisks

	\\ Failed to initialise card!

.carderr
	JSR ReportError
	EQUB &FF
	EQUS "Card?",0
}

	\\ Reset Discs in Drives.
	\\ Only done if FDC not present of disabled.
.MMC_LoadDisks
{
	LDX PagedRomSelector_RAMCopy
	LDA PagedROM_PrivWorkspaces,X
	BPL exit

	LDA #0
	STA &B9

	LDX #3

.loop	STX &B8
	TXA
	JSR LoadDriveA
	DEX
	BPL loop

.exit	RTS
}


	\\ If sector 0 set, check it's the same card
	\\ If ok Z=1
.MMC_CheckCardID
{
	JSR VID_check_report

	LDA MMC_SECTOR
	ORA MMC_SECTOR+1
	ORA MMC_SECTOR+2
	BEQ cid_x

	JSR MMC_GetCIDCRC		; YA=CRC16
	CMP MMC_CIDCRC+1
	BNE errCardChanged

	CPY MMC_CIDCRC
	BNE errCardChanged

.cid_x	RTS

.errCardChanged
	LDA #0
	STA MMC_STATE
	JSR ReportError
	EQUB &FF
	EQUS "Wrong card!",0
}
};MMC_BEGIN1


	\\ **** END MMC TRANSACTION ****
.MMC_END
{
	LDX #9

.loop1	LDA MMC_WSP,X
	STA &BC,X
	DEX
	BPL loop1

	RTS
}