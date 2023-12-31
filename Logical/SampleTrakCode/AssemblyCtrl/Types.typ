
TYPE
	AsmStateEnum : 
		( (*State of the assembly control task*)
		ASM_IDLE,
		ASM_POWER_ON,
		ASM_FIND_ALL_SHUTTLES,
		ASM_READ_FROM_SHUTTLE,
		ASM_TRACK_SHUTTLE,
		ASM_WRITE_TO_SHUTTLE,
		ASM_MOVE_SHUTTLE,
		ASM_CHECK_FOR_MORE,
		ASM_RUNNING,
		ASMSTOP_FIND_ALL_SHUTTLES,
		ASMSTOP_READ_FROM_SHUTTLE,
		ASMSTOP_WRITE_TO_SHUTTLE,
		ASMSTOP_MOVE_SHUTTLE,
		ASMSTOP_CHECK_FOR_MORE,
		ASM_ERROR
		);
END_TYPE
