	\-------------------------------------------------------------------\
	\ Title   : Ultra DFS                                               \
	\ Author  : Martin Mather 2016                                      \
	\ Compiler: BeebAsm V1.08                                           \
	\-------------------------------------------------------------------\
	\ Module  : MMC_OSWORD7F.asm                                        \
	\-------------------------------------------------------------------\


	\\ **** OSWORD &7F EMULATION ****

	\ Active drive must already be set on entry.
	\ Entry: If >1.20 Y:X->control block.
	\ (2.24 & 2.26 use &C7 as the osword pointer, and
	\ &B0 is used by other parts of its 8271 emulation code.)
	\ Exit: A=result, Z=A=0
.MMC_OSWORD7F
{
	owbptr%=&B0	; Pointer to parameter block	
	owfdsec%=&B2	; FDC sector
	owfdcop%=&B3	; FDC operation
	owsec%=&B4	; MMC Sector (16 bit)

	\ 8271 op codes
	Fread=&53
	Fwrite=&4B
	Fverify=&5F
	Fformat=&63

	\ 8271 error codes
	Rdrvnotrdy=&10
	Rwritepro=&12
	Rnottrack0=&14
	Rnosector=&1E

	JSR MMC_Route_ActiveDrv

IF sys=120
	LDX owbptr%
	LDY owbptr%+1
ENDIF

	JSR MMC_BEGIN2			; A, X & Y preserved, but word &B0 may be corrupted!

	STX owbptr%
	STY owbptr%+1

	LDY #0
	STY byteslastsec%
	STY owfdsec%

	INY				; Y=1
	LDX #2
	JSR CopyVarsB0BA		; Copy buffer address to &BC-&BD;&1074-&1075

	JSR ow7F			; returns result in A

	\ Copy result to param block.

	PHA
	LDY #5
	LDA (owbptr%),Y			; no. of parameters
	CLC
	ADC #7
	TAY
	PLA				; Z=A=0
	STA (owbptr%),Y

	RTS

	\ Unrecognise FDC commands are ignored
.owuknown
	LDA #0
	RTS

.ow7F	LDX ActiveDrv			; Check drive state
	LDA DRIVE_INDEX4,X
	ROL A
	BPL owdrvnotrdy			; If drive not loaded

	AND #&10*2
	PHP

	LDY #6				; Y=6
	LDA (owbptr%),Y			; FDC command
	STA owfdcop%

	PLP
	BEQ labelx1			; If disk formatted

	\ The only thing we can do with an unformatted disk is format it!

	CMP #Fformat			; format
	BEQ owrw
	BNE ownosector

.labelx1
	CMP #Fverify			; verify
	BEQ owrw

	CMP #Fformat			; format
	BEQ labelx2

	SEC
	ROR owfdsec%			; Set bit 7 (flag there is a sector parameter)

	CMP #Fread			; read
	BEQ owrw

	CMP #Fwrite			; write
	BNE owuknown

	\\ Check Write protect
.labelx2
	LDA DRIVE_INDEX4,X		; Bit 5 set = protected
	AND #&20
	BEQ owrw

	LDA #Rwritepro
	RTS

.ownosector
	LDA #Rnosector
	RTS

.owdrvnotrdy
	LDA #Rdrvnotrdy
	RTS


	\\ Check 3 params (sec/trk/len)
.owrw

	\\ Calc 1st disc sector = trk*10+sec
	LDA #0
	STA owsec%+1

	INY				; Y=7
	LDA (owbptr%),Y			; TRACK
	CMP #80				; Check track no<80
	BCS ownosector

	ASL A
	STA owsec%
	ASL A
	ROL owsec%+1
	ASL A
	ROL owsec%+1
	ADC owsec%
	STA owsec%
	BCC owsk1

	INC owsec%+1

.owsk1
	INY				; Y=8

	ASL owfdsec%			; ?owfdsec%=0, C=Sector parameter flag
	BCC owsk2			; i.e. if verify/format

	LDA (owbptr%),Y			; SECTOR
	CMP #10				; Check sector no.<10
	BCS ownosector

	CLC
	STA owfdsec%
	ADC owsec%
	STA owsec%
	BCC owsk2

	INC owsec%+1

.owsk2
	INY				; Y=9
	LDA (owbptr%),Y			; LENGTH
	AND #&1F
	BEQ owretok			; If LENGTH=0 just exit.

	STA seccount%

	\ Check last sector no. to read < 11
	CLC
	ADC owfdsec%			; LENGTH + SECTOR
	CMP #11
	BCS ownosector

	\\ Get mmc addr of 1st sector
.owsk3
	LDX ActiveDrv
	JSR DiskStart_DrvX

	CLC
	LDA sec%
	ADC owsec%
	STA sec%
	LDA sec%+1
	ADC owsec%+1
	STA sec%+1
	BCC owsk4

	INC sec%+2

.owsk4
	LDA owfdcop%
	CMP #Fwrite			; Write
	BEQ owwrite

	CMP #Fformat
	BEQ owwrite			; Format

	CMP #Fverify
	BEQ owretok			; Verify

	JSR MMC_ReadBlock

.owexit
	LDA TubeNoTransferIf0
	BEQ owretok

	JSR TUBE_RELEASE_NoCheck

.owretok
	LDA #0
	RTS

.owwrite
	JSR MMC_WriteBlock
	JMP owexit
}
