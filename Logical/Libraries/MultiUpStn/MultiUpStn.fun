
{REDUND_ERROR} FUNCTION_BLOCK MultiUpStn (*Buffer substations distribute shuttles to the slots when given the release command*) (*$GROUP=User,$CAT=User,$GROUPICON=User.png,$CATICON=User.png*)
	VAR_INPUT
		Enable : BOOL;
		ToolingClear : BOOL;
		MotionParameters : REFERENCE TO ShMotionParType;
		SelfDetails : ARRAY[0..MAX_NUM_SLOTS] OF SubstationDetailsType; (*Index 0 is the buffer. Indeces 1-MAX are the slots in order from closest to the buffer to farthest *)
		TargetDetails : SubstationDetailsType;
		ReleaseShuttles : BOOL;
		Recover : BOOL;
		Purge : BOOL;
		ErrorReset : BOOL;
		UserData : REFERENCE TO ARRAY[0..MAX_NUM_SLOTS] OF UserDataType; (*1-MAX are the slots in order from closest to the buffer to farthest *)
	END_VAR
	VAR_OUTPUT
		FillingSlots : BOOL;
		SlotsFilled : BOOL;
		RecoveryDone : BOOL;
		Error : BOOL;
		ErrorText : STRING[100];
	END_VAR
	VAR
		Internal : StationInternalType;
	END_VAR
END_FUNCTION_BLOCK
