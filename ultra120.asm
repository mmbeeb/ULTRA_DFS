	\\ Ultra DFS 1.20
	\\ ultra120.asm
	\\ Compiler: BeebAsm V1.08
	\\ by Martin Mather

	_MMC_DEVICE_ = 'M'

	sys=120
	ultra = TRUE

	ultra2 = FALSE

	INCLUDE "dfs.asm"

	SAVE "ULTRA120.ROM", &8000, &C000
