(*
Substation list*)

TYPE
	SubstationList_enum : 
		(
		STN_1_BUFFER,
		STN_1_1,
		STN_1_2,
		STN_1_3,
		STN_1_4,
		STN_1_5,
		STN_1_6,
		STN_2_BUFFER,
		STN_2_1,
		STN_2_2,
		STN_2_3,
		STN_2_4,
		STN_2_5,
		STN_2_6,
		STN_3_BUFFER,
		STN_3_1,
		STN_3_2,
		STN_3_3,
		STN_3_4,
		STN_3_5,
		STN_3_6,
		STN_4_BUFFER,
		STN_4_1,
		STN_4_2,
		STN_4_3,
		STN_4_4,
		STN_4_5,
		STN_4_6,
		STOP_POSITION,
		SUBSTATION_COUNT
		);
END_TYPE

(*
Userdata Structure*)

TYPE
	UserDataType : 	STRUCT 
		Red : REAL; (*The red value of the shuttle color*)
		Green : REAL; (*The green value of the shuttle color*)
		Blue : REAL; (*The blue value of the shuttle color*)
		Destination : SubstationDetailsType; (*The substation that the shuttle is currently being told to go to*)
		ShuttleSerialNum : STRING[12]; (*Shuttle serial number*)
		Recovered : BOOL; (*Whether or not a station has recovered the shuttle*)
	END_STRUCT;
END_TYPE

(*
Structure for information on all substations on the assembly*)

TYPE
	SubstationDetailsType : 	STRUCT 
		SubstationID : SubstationList_enum; (*The enumeric "name" of this station*)
		SectorReference : UDINT; (*The reference to substation's sector*)
		ProcessPointReference : UDINT; (*The reference to substation's process point*)
		Position : LREAL; (*Offset of the substation in meters relative to the start of its sector*)
		MoveMethod : MoveMethodEnum; (*How the shuttle should be sent to the station (Absolute or Velocity)*)
	END_STRUCT;
	MoveMethodEnum : 
		(
		VELOCITY,
		ABSOLUTE
		);
END_TYPE

(*
Motion parameters for substations move commands*)

TYPE
	ShMotionParType : 	STRUCT 
		Velocity : REAL; (*The velocity for all shuttles on the assembly*)
		Acceleration : REAL; (*The acceleration for all shuttles on the assembly*)
		Deceleration : REAL; (*The deceleration for all shuttles on the assembly*)
	END_STRUCT;
END_TYPE

(**)
(*Structures for station FUB*)

TYPE
	StationInternalType : 	STRUCT 
		BufferState : StnBufferStateEnum; (*The state of the substation's buffer*)
		SlotsState : StnSlotsStateEnum; (*The state of the substation's slots*)
		RecoveryState : StnRecoveyrStateEnum; (*The state of the substation's recovery sequence*)
		SlotEnabled : ARRAY[0..MAX_NUM_SLOTS]OF BOOL; (*1-MAX are the slots in order from closest to the buffer to farthest *)
		FarthestSlot : USINT; (*The farthest active slot in the station*)
		ActiveIndex : USINT;
		BufferIndex : USINT;
		SlotIndex : USINT;
		RecoveryIndex : USINT;
		RecovBufferIndex : USINT;
		FubIndex : USINT;
		StationBuffer : tbAsyncShuttleBufferType;
		SlotShuttleRefs : ARRAY[0..MAX_NUM_SLOTS]OF McAxisType;
		TempSlotsFilled : USINT;
		TempUserdataWritten : USINT;
		TempShuttleReleased : USINT;
		BehindBuffer : UINT;
		ActiveSlots : USINT;
		SendAway : UINT;
		RecoveryFilledSlots : BOOL;
		Fubs : StationInternalFubsType; (*The various function blocks needed for a substation*)
	END_STRUCT;
	StationInternalFubsType : 	STRUCT 
		TrgPointEnable : MC_BR_TrgPointEnable_AcpTrak; (*Fub for monitoring the process point for shuttles*)
		TrgPointGetInfo : MC_BR_TrgPointGetInfo_AcpTrak; (*Fub for getting the axis reference of shuttles passing the process point*)
		ShCopyUserData : ARRAY[0..MAX_NUM_SLOTS]OF MC_BR_ShCopyUserData_AcpTrak; (*Fub for reading and writing userdata to and from the shuttle*)
		ElasticMoveAbs : ARRAY[0..MAX_NUM_SLOTS]OF MC_BR_ElasticMoveAbs_AcpTrak;
		RoutedMoveAbs : ARRAY[0..MAX_NUM_SLOTS]OF MC_BR_RoutedMoveAbs_AcpTrak; (*Fub for enacting an absolute move on the shuttle*)
		SecGetShuttleSel : MC_BR_SecGetShuttleSel_AcpTrak;
		ShReadInfo : ARRAY[0..MAX_NUM_SLOTS]OF MC_BR_ShReadInfo_AcpTrak;
		SecStop : MC_BR_SecStop_AcpTrak;
		RecoveryTimer : TON := (PT:=T#1000ms);
		ShSwitchSector : MC_BR_ShSwitchSector_AcpTrak;
		BarrierCommand : MC_BR_BarrierCommand_AcpTrak;
		BarrierReadInfo : MC_BR_BarrierReadInfo_AcpTrak;
	END_STRUCT;
	StnBufferStateEnum : 
		(
		BUF_DISABLED,
		BUF_RECOVERING,
		BUF_WAIT_FOR_SH,
		BUF_READ_SH,
		BUF_PUT_ON_SECT,
		BUF_STAGE_SH,
		BUF_CLEAR_QUEUE,
		BUF_ERROR
		);
	StnSlotsStateEnum : 
		(
		SLOTS_DISABLED,
		SLOTS_RECOVERING,
		SLOTS_WAIT_FOR_QUEUE,
		SLOTS_READ_USERDATA,
		SLOTS_MOVE_TO_SLOT,
		SLOTS_CONFIRM_SLOTS_FULL,
		SLOTS_WAIT_FOR_RELEASE,
		SLOTS_RELEASE_SHUTTLES,
		SLOTS_CONFIRM_RELEASE,
		SLOTS_SEND_ON,
		SLOTS_ERROR
		);
	StnRecoveyrStateEnum : 
		(
		RECOV_DISABLED,
		RECOV_FIND_ALL_1,
		RECOV_PUT_ON_SECT,
		RECOV_CONFIRM_PUT_ON_SECT,
		RECOV_SEND_REVERSE,
		RECOV_CONFIRM_REVERSE,
		RECOV_FIND_ALL_2_BUFFER,
		RECOV_FIND_ALL_2,
		RECOV_SEND_FORWARD,
		RECOV_CONFIRM_FORWARD,
		RECOV_MARK_RECOVERED,
		RECOV_CHECK_REMAINING,
		RECOV_DONE,
		RECOV_ERROR
		);
END_TYPE
