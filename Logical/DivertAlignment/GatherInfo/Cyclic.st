
PROGRAM _CYCLIC
	(* Insert code here *)
	CASE GatherState OF
		GATHER_IDLE:
			// Wait for command, then clear the schematic structure and enable the AsmGetSeg and AsmGetSec FUBs
			IF CmdGather THEN
				brsmemset(ADR(AssemblySchematics),0,SIZEOF(AssemblySchematics));
				AsmGetSeg.Enable := TRUE;
				AsmGetSec.Enable := TRUE;
				GatherState := GATHER_SEG_AND_SEC;
			END_IF
				
		GATHER_SEG_AND_SEC:
			// Wait for validity
			IF AsmGetSeg.Valid AND AsmGetSec.Valid THEN
				// Clear the "next" signals
				AsmGetSeg.Next := FALSE;
				AsmGetSec.Next := FALSE;
				// Plug the segment and sectors into the respective get infor FUBs
				SegGetInfo.Segment := ADR(AsmGetSeg.Segment);
				SecGetInfo.Sector := ADR(AsmGetSec.Sector);
				// Execute the FUBs
				SegGetInfo.Execute := TRUE;
				SecGetInfo.Execute := TRUE;
				GatherState := GATHER_SEG_AND_SEC_INFO;
			END_IF
			
		GATHER_SEG_AND_SEC_INFO:
			// Wait for the SegGetInfo and SecGetInfo FUBs to finish
			IF SegGetInfo.Done AND SecGetInfo.Done THEN 
				// Record the segment information (use the segment ID as the index)
				AssemblySchematics.Segment[SegGetInfo.SegmentInfo.ID].Reference := AsmGetSeg.Segment;
				AssemblySchematics.Segment[SegGetInfo.SegmentInfo.ID].Name := SegGetInfo.SegmentInfo.Name;
				AssemblySchematics.Segment[SegGetInfo.SegmentInfo.ID].ID := SegGetInfo.SegmentInfo.ID;
				AssemblySchematics.Segment[SegGetInfo.SegmentInfo.ID].Type := SegGetInfo.SegmentInfo.Type;
				AssemblySchematics.Segment[SegGetInfo.SegmentInfo.ID].StartFrame := SegGetInfo.SegmentInfo.StartFrame;
				AssemblySchematics.Segment[SegGetInfo.SegmentInfo.ID].EndFrame := SegGetInfo.SegmentInfo.EndFrame;
				// Record the sector information (store them in the order they are found)
				AssemblySchematics.Sectors[AsmGetSec.TotalCount - AsmGetSec.RemainingCount - 1].Reference := AsmGetSec.Sector;
				AssemblySchematics.Sectors[AsmGetSec.TotalCount - AsmGetSec.RemainingCount - 1].Name := SecGetInfo.SectorInfo.Name;				
				AssemblySchematics.Sectors[AsmGetSec.TotalCount - AsmGetSec.RemainingCount - 1].Length := SecGetInfo.SectorInfo.Length;
				AssemblySchematics.Sectors[AsmGetSec.TotalCount - AsmGetSec.RemainingCount - 1].Type := SecGetInfo.SectorInfo.Type;
				// Reset the execute commands
				SegGetInfo.Execute := FALSE;
				SecGetInfo.Execute := FALSE;
				// If there are more segments, iterate
				IF AsmGetSeg.RemainingCount > 0 THEN
					AsmGetSeg.Next := TRUE;
					GatherState := GATHER_SEG_AND_SEC;
				END_IF
				// If there are more sectors, iterate
				IF AsmGetSec.RemainingCount > 0 THEN
					AsmGetSec.Next := TRUE;
					GatherState := GATHER_SEG_AND_SEC;
				END_IF
				// If there are no more segments and no more sectors, the task is done
				IF AsmGetSeg.RemainingCount = 0 AND AsmGetSec.RemainingCount = 0 THEN
					AsmGetSeg.Enable := FALSE;
					AsmGetSec.Enable := FALSE;
					GatherState := GATHER_DIVERTS;
				END_IF
			END_IF
			
		GATHER_DIVERTS:
			// Use the CheckForDiverts function
			CheckForDiverts(ADR(AssemblySchematics));
			GatherState := GATHER_SHUTTLE;
			
		GATHER_SHUTTLE:
			// Get the reference of the shuttle on the trak
			AsmGetShuttle.Enable := TRUE;
			IF AsmGetShuttle.Valid THEN
				RoutedMoveAbs.Axis := ADR(AsmGetShuttle.Axis);
				ShReadInfo.Axis := ADR(AsmGetShuttle.Axis);
				ShReadInfo.Enable := TRUE;
				ShReadSeg.Axis := ADR(AsmGetShuttle.Axis);
				ShReadSeg.Enable := TRUE;
				GatherState := GATHER_MOVE_TO_START;
			END_IF
		
		GATHER_MOVE_TO_START:
			// ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! !
			// ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! !
			// ! ! !  CHANGE THE STATES SO THAT DIVERTS CAN BE FOUND ON ROUTES TOO   ! ! !
			// ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! !
			// ! ! !           MAKE SHUTTLE CHANGE COLOR WHEN DIVERT FOUND           ! ! !
			// ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! !
			// ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! !
			
			// Move to the start of the sector at full speed
			RoutedMoveAbs.Sector := ADR(AssemblySchematics.Sectors[SectorIndex].Reference);
			RoutedMoveAbs.Axis := ADR(AsmGetShuttle.Axis);
			RoutedMoveAbs.Position := 0;
			RoutedMoveAbs.Velocity := 4;
			RoutedMoveAbs.Acceleration := 40;
			RoutedMoveAbs.Deceleration := 40;
			RoutedMoveAbs.AdvancedParameters.StartDirection := mcDIR_UNDEFINED;
			RoutedMoveAbs.AdvancedParameters.EndDirection := mcDIR_UNDEFINED;
			RoutedMoveAbs.AdvancedParameters.ShuttleOrientation := mcDIR_UNDEFINED;
			RoutedMoveAbs.Execute := TRUE;
			IF RoutedMoveAbs.Done THEN
				RoutedMoveAbs.Execute := FALSE;
				GatherState := GATHER_MOVE_ALONG_SEC;
			END_IF
				
		GATHER_MOVE_ALONG_SEC:
			// Move to the end of the sector in the positive direction
			ElasticMoveAbs.Axis := ADR(AsmGetShuttle.Axis);
			ElasticMoveAbs.Position := AssemblySchematics.Sectors[SectorIndex].Length;
			ElasticMoveAbs.Velocity := TestVelocity;
			ElasticMoveAbs.Acceleration := 40;
			ElasticMoveAbs.Deceleration := 40;
			ElasticMoveAbs.Execute := TRUE;
			IF ElasticMoveAbs.Active THEN
				GatherState := GATHER_MONITOR_FOR_MIDPOINT;
			END_IF
			
		GATHER_MONITOR_FOR_MIDPOINT:
			// Constantly compare the current seg position to the divert seg midpoints
			// Execute a stop if within DIV_MIDPOINT_TOLERANCE of one
			FOR DivertIndex:=0 TO NUM_DIVERTS DO
				IF NOT AssemblySchematics.Diverts[DivertIndex].Measured THEN
					// If the shuttle is on the same segment as the divert's first segment then compare the positions
					IF (ShReadInfo.ShuttleInfo.CurrentValues.SegmentPosition.Name = AssemblySchematics.Diverts[DivertIndex].SegName[0]) THEN
						// If the shuttles current position on the segment is within DIV_MIDPOINT_TOLERANCE of the midpoint then stop and take the measurement
						IF (ShReadInfo.ShuttleInfo.CurrentValues.SegmentPosition.Position > AssemblySchematics.Diverts[DivertIndex].DivertMid[0] - DIV_MIDPOINT_TOLERANCE) AND
							(ShReadInfo.ShuttleInfo.CurrentValues.SegmentPosition.Position < AssemblySchematics.Diverts[DivertIndex].DivertMid[0] + DIV_MIDPOINT_TOLERANCE) THEN
							AssemblySchematics.Diverts[DivertIndex].Measured := TRUE;
							ElasticMoveAbs.Execute := FALSE;
							SecStop.Sector := ADR(AssemblySchematics.Sectors[SectorIndex].Reference);
							SecStop.Execute := TRUE;
							GatherState := GATHER_ACKNOWLEDGE;
							EXIT;
						END_IF
					// If the shuttle is on the same segment as the divert's second segment then compare the positions
					ELSIF (ShReadInfo.ShuttleInfo.CurrentValues.SegmentPosition.Name = AssemblySchematics.Diverts[DivertIndex].SegName[1]) THEN
						// If the shuttles current position on the segment is within DIV_MIDPOINT_TOLERANCE of the midpoint then stop and take the measurement
						IF (ShReadInfo.ShuttleInfo.CurrentValues.SegmentPosition.Position > AssemblySchematics.Diverts[DivertIndex].DivertMid[1] - DIV_MIDPOINT_TOLERANCE) AND
							(ShReadInfo.ShuttleInfo.CurrentValues.SegmentPosition.Position < AssemblySchematics.Diverts[DivertIndex].DivertMid[1] + DIV_MIDPOINT_TOLERANCE) THEN
							AssemblySchematics.Diverts[DivertIndex].Measured := TRUE;
							ElasticMoveAbs.Execute := FALSE;
							SecStop.Sector := ADR(AssemblySchematics.Sectors[SectorIndex].Reference);
							SecStop.Execute := TRUE;
							GatherState := GATHER_ACKNOWLEDGE;
							EXIT;
						END_IF
					END_IF
				END_IF
			END_FOR
			// If the move finishes, the shuttle reached the end of the sector. Increment the sector index
			IF ElasticMoveAbs.Done THEN
				ElasticMoveAbs.Execute := FALSE;
				SectorIndex := SectorIndex + 1;
				// if the index is less than or equal to the limit, check that it is not an empty entry
				IF SectorIndex <= NUM_SECTORS THEN
					// If the entry is not empty, go to the start of that sector
					IF AssemblySchematics.Sectors[SectorIndex].Length <> 0 THEN
						GatherState := GATHER_MOVE_TO_START;
					// If the entry is empty, all sectors have been checked
					ELSE
						GatherState := GATHER_DONE;
					END_IF
				// If the index is greater than the limit, all entries have been checked
				ELSE
					GatherState := GATHER_DONE;
				END_IF
			END_IF
				
				
		
		GATHER_ACKNOWLEDGE:
			// When the command is given, go back to moving along the sector
			IF SecStop.Done THEN
				SecStop.Execute := FALSE;
				AcknowledgeTimer.PT := AcknowledgeTime;
				AcknowledgeTimer.IN := TRUE;
			END_IF
			IF AcknowledgeTimer.Q THEN
				AcknowledgeTimer.IN := FALSE;
				GatherState := GATHER_MOVE_ALONG_SEC;
			END_IF
		
		GATHER_DONE:
			DivertIndex := 0;
			SectorIndex := 0;
			IF NOT CmdGather THEN
				GatherState := GATHER_IDLE;
			END_IF
				
	END_CASE
			
	AsmGetSeg();
	AsmGetSec();
	SecStop();
	SegGetInfo();
	SecGetInfo();
	AsmGetShuttle();
	RoutedMoveAbs();
	ElasticMoveAbs();
	ShReadInfo();
	ShReadSeg();
	AcknowledgeTimer();
	
END_PROGRAM
