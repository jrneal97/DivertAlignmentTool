(*Structure for holding information about the layout of the assembly*)

TYPE
	AsmSchemType : 	STRUCT 
		AsmReference : McAssemblyType;
		Segment : ARRAY[0..NUM_SEGMENTS]OF SegSchemType;
		Sectors : ARRAY[0..NUM_SECTORS]OF SecSchemType;
		Diverts : ARRAY[0..NUM_DIVERTS]OF DivSchemType;
		VirtualShuttles : ARRAY[0..NUM_SECTORS]OF McAxisType;
		Svg : SvgSchemType;
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
		Measurements : DivMeasType;
		Alignment : LREAL;
		Overlap : LREAL;
		SegName : ARRAY[0..1]OF STRING[32];
		SegID : ARRAY[0..1]OF UINT;
		Found : BOOL;
		SecRef : ARRAY[0..1]OF McSectorType;
		SecName : ARRAY[0..1]OF STRING[32];
		PosOnSec : ARRAY[0..1]OF LREAL;
		DivertMid : ARRAY[0..1]OF LREAL;
	END_STRUCT;
	DivMeasType : 	STRUCT 
		Measured : BOOL;
		ErrorFromMid : ARRAY[0..1]OF LREAL;
		ErrorDiff : LREAL;
	END_STRUCT;
	SvgSchemType : 	STRUCT 
		Content : STRING[20000];
		Transform : STRING[10000];
		Viewbox : SvgViewboxType;
	END_STRUCT;
	SvgViewboxType : 	STRUCT 
		MinX : DrawingNumberType;
		MaxX : DrawingNumberType;
		MinY : DrawingNumberType;
		MaxY : DrawingNumberType;
		Width : DrawingNumberType;
		Height : DrawingNumberType;
		BorderWidth : USINT := 100;
	END_STRUCT;
	DrawingNumberType : 	STRUCT 
		Value : INT;
		String : STRING[20];
	END_STRUCT;
END_TYPE

(*
Types for the GetSegments FUB*)

TYPE
	DvAlnGetSegInternalType : 	STRUCT 
		State : DvAlnGetSegStateEnum;
		AsmGetSeg : MC_BR_AsmGetSegment_AcpTrak;
		SegGetInfo : MC_BR_SegGetInfo_AcpTrak;
	END_STRUCT;
	DvAlnGetSegStateEnum : 
		(
		GET_SEG_IDLE,
		GET_SEG_REF,
		GET_SEG_INFO,
		GET_SEG_DONE
		);
END_TYPE

(*
Types for the GetSectors FUB*)

TYPE
	DvAlnGetSecInternalType : 	STRUCT 
		State : DvAlnGetSecStateEnum;
		AsmGetSec : MC_BR_AsmGetSector_AcpTrak;
		SecGetInfo : MC_BR_SecGetInfo_AcpTrak;
		SecAddVirtualSh : MC_BR_SecAddShuttle_AcpTrak;
	END_STRUCT;
	DvAlnGetSecStateEnum : 
		(
		GET_SEC_IDLE,
		GET_SEC_REF,
		GET_SEC_INFO,
		GET_SEC_DONE
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
