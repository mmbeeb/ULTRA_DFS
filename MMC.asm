	\-------------------------------------------------------------------\
	\ Title   : Ultra DFS                                               \
	\ Author  : Martin Mather 2016                                      \
	\ Compiler: BeebAsm V1.08                                           \
	\-------------------------------------------------------------------\
	\ Module  : MMC.asm                                                 \
	\-------------------------------------------------------------------\


	INCLUDE "MMC_Functions.asm"
	INCLUDE "MMC_FAT.asm"		;FAT
	INCLUDE "MMC_DUTILS.asm"	;DUTILS commands
	INCLUDE "MMC_OSWORD7F.asm"	;OSWORD &7F emulation
	INCLUDE "MMC_HighLevel.asm"	;Hardware high level code.

	\\ Include hardware low level code here!

IF _MMC_DEVICE_='U'
	INCLUDE "MMC_Device_UserPort.asm"
ELIF _MMC_DEVICE_='M'
	INCLUDE "MMC_Device_MemoryMapped.asm"
ENDIF

.errWrite2
	TYA
	JSR MMC_ReportErrS
	EQUB &C5
	EQUS "MMC Write response fault "
	BRK


\ End of file
