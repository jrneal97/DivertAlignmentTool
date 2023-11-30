(*********************************************************************************
 * Copyright: B&R Industrial Automation GmbH 
 * Author:    nealj 
 * Created:   November 17, 2023/9:05 AM 
 * 
 *********************************************************************************)

FUNCTION MeasureDivert
			
	// Take the measurement of the shuttle relative to the midpoint for each segment of the divert
	FOR SegMeasIndex:=0 TO 3 DO
		// If this segment from the ShReadSeg FUB is the fist segment of the divert, record the distance from the mdipoint
		IF ShSegInfo.SegmentSetValues[SegMeasIndex].SegmentID = Schematic.Diverts[DivertIndex].SegID[0] THEN
			Schematic.Diverts[DivertIndex].Measurements.ErrorFromMid[0] := ABS(ShSegInfo.SegmentCurrentValues[SegMeasIndex].Position - Schematic.Diverts[DivertIndex].DivertMid[0]);
			// If this segment from the ShReadSeg FUB is the segment segment of the divert, record the distance from the mdipoint
		ELSIF ShSegInfo.SegmentSetValues[SegMeasIndex].SegmentID = Schematic.Diverts[DivertIndex].SegID[1] THEN
			Schematic.Diverts[DivertIndex].Measurements.ErrorFromMid[1] := ABS(ShSegInfo.SegmentCurrentValues[SegMeasIndex].Position - Schematic.Diverts[DivertIndex].DivertMid[1]);
		END_IF
	END_FOR
	// Take the difference between the two offsets
	Schematic.Diverts[DivertIndex].Measurements.ErrorDiff := ABS(Schematic.Diverts[DivertIndex].Measurements.ErrorFromMid[0] - Schematic.Diverts[DivertIndex].Measurements.ErrorFromMid[1]);
	
	//Record that the measurement process is complete
	Schematic.Diverts[DivertIndex].Measurements.Measured := TRUE;
			
END_FUNCTION