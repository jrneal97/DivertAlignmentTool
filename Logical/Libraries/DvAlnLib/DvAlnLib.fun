
FUNCTION CheckForDiverts : BOOL
	VAR_INPUT
		Schematic : REFERENCE TO AsmSchemType;
	END_VAR
	VAR
		IsDivert : BOOL;
		Overlap : LREAL;
		MainSegDivMidpoint : LREAL;
		SubSegDivMidpoint : LREAL;
		ReferenceSeg : SegSchemType;
		ReferenceSegMidpoint : LREAL;
		OtherSeg : SegSchemType;
		OtherSegMidpoint : LREAL;
		ReferenceMode : ReferenceModeEnum;
		ComparisonMode : ComparisonModeEnum;
		Hypotenuse : LREAL;
		Horizontal : LREAL;
		MainIndex : UINT;
		SubIndex : UINT;
		DivertIndex : UINT;
	END_VAR
END_FUNCTION

FUNCTION PointToLineDist : LREAL
	VAR_INPUT
		P : McFrameType; (*The point*)
		L1 : McFrameType; (*The first point on the line*)
		L2 : McFrameType; (*The second point on the line*)
	END_VAR
	VAR
		Distance : LREAL; (*The distance between the point and the line*)
	END_VAR
END_FUNCTION

FUNCTION PointToPointDist : LREAL
	VAR_INPUT
		P1 : McFrameType; (*The first point*)
		P2 : McFrameType; (*The second point*)
	END_VAR
	VAR
		Distance : LREAL; (*The distance between the two points*)
	END_VAR
END_FUNCTION
