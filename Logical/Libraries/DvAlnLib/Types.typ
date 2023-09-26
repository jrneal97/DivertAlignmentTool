(*Structure for holding information about the layout of the assembly*)

TYPE
	AsmSchemType : 	STRUCT 
		Segment : ARRAY[0..NUM_SEGMENTS]OF SegSchemType;
		Sectors : ARRAY[0..NUM_SECTORS]OF SecSchemType;
		Diverts : ARRAY[0..NUM_DIVERTS]OF DivSchemType;
	END_STRUCT;
	SegSchemType : 	STRUCT 
		Reference : McSegmentType;
		Name : STRING[32];
		ID : UINT;
		StartFrame : McFrameType;
		EndFrame : McFrameType;
		Type : McAcpTrakSegTypeEnum;
		Divert : {REDUND_UNREPLICABLE} SegDivertInfoType;
	END_STRUCT;
	SegDivertInfoType : 	STRUCT 
		Member : ARRAY[0..1]OF BOOL;
		DivertID : ARRAY[0..1]OF UINT;
	END_STRUCT;
	SecSchemType : 	STRUCT 
		Reference : McSectorType;
		Name : STRING[32];
		Length : LREAL;
		Type : McAcpTrakSecTypeEnum;
	END_STRUCT;
	DivSchemType : 	STRUCT 
		Measured : BOOL;
		Alignment : LREAL;
		Overlap : LREAL;
		SegName : ARRAY[0..1]OF STRING[32];
		SegID : ARRAY[0..1]OF UINT;
		DivertMid : ARRAY[0..1]OF LREAL;
	END_STRUCT;
END_TYPE

(*
States for the CheckPair FUB*)

TYPE
	CheckPairStateEnum : 
		(
		CHK_PR_DIV_IDLE,
		CHK_PR_DIV_ACTIVE,
		CHK_PR_DIV_DONE
		);
END_TYPE

(*
Possible decisions for deciding if two segemtns form a divert*)

TYPE
	ReferenceModeEnum : 
		(
		REFERENCE_NOT_SELECTED,
		MAIN_SEG_IS_REF,
		SUB_SEG_IS_REF,
		REFERENCE_NOT_NEEDED
		);
	ComparisonModeEnum : 
		(
		COMPARE_NOT_SELECTED,
		COMPARE_AA_AA,
		COMPARE_AA_AB,
		COMPARE_AA_BA,
		COMPARE_AB_AB,
		COMPARE_AB_BA,
		COMPARE_BA_BA,
		CANNOT_BE_DIVERT
		);
END_TYPE
