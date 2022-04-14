	\\ Acorn DFS 2.26
	\\ ultra226.asm
	\\ Compiler: BeebAsm V1.08
	\\ Disassembly by Martin Mather

	_MMC_DEVICE_ = 'M'

	sys=226
	ultra = TRUE

	ultra2=FALSE

	INCLUDE "dfs.asm"

	SAVE "ULTRA226.ROM", &8000, &C000
