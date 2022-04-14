	\-------------------------------------------------------------------\
	\ Title   : Ultra DFS                                               \
	\ Author  : Martin Mather 2015                                      \
	\ Compiler: BeebAsm V1.08                                           \
	\-------------------------------------------------------------------\
	\ Module  : mmc.asm                                                 \
	\-------------------------------------------------------------------\


	INCLUDE "mmc_functions.asm"
	INCLUDE "mmc_dutils.asm"
	INCLUDE "mmc_drives.asm"
	INCLUDE "mmc_fat.asm"

	\\ Include Low Level MMC Code here

IF _MMC_DEVICE_='U'
	INCLUDE "mmc_interface_UserPort.asm"
ELIF _MMC_DEVICE_='M'
	INCLUDE "mmc_interface_MemoryMapped.asm"
ENDIF

.errWrite2
	TYA
	;;;;;	JSR ReportMMCErrS
	JSR mmc_report_error
	EQUB &C5
	EQUS "MMC Write response fault "
	NOP				; Print sector
	;;;	BRK

	\\ Include high level MMC code here

INCLUDE "mmc_highlevel.asm"
