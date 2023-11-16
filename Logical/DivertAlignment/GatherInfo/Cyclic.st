
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
				MinX.Value := 0;
				MinY.Value := 0;
				MaxX.Value := 0;
				MaxY.Value := 0;
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
				// Record the min and max values for the X values
				IF (SegGetInfo.SegmentInfo.StartFrame.Pos.X - BorderWidth) < (MinX.Value) THEN
					MinX.Value := TRUNC(SegGetInfo.SegmentInfo.StartFrame.Pos.X - BorderWidth);
				END_IF
				IF (SegGetInfo.SegmentInfo.EndFrame.Pos.X - BorderWidth) < (MinX.Value) THEN
					MinX.Value := TRUNC(SegGetInfo.SegmentInfo.EndFrame.Pos.X - BorderWidth);
				END_IF
				IF (SegGetInfo.SegmentInfo.StartFrame.Pos.X + BorderWidth) > (MaxX.Value) THEN
					MaxX.Value := TRUNC(SegGetInfo.SegmentInfo.StartFrame.Pos.X + BorderWidth);
				END_IF
				IF (SegGetInfo.SegmentInfo.EndFrame.Pos.X + BorderWidth) > (MaxX.Value) THEN
					MaxX.Value := TRUNC(SegGetInfo.SegmentInfo.EndFrame.Pos.X + BorderWidth);
				END_IF
				// Record the min and max values for the Y values
				IF (SegGetInfo.SegmentInfo.StartFrame.Pos.Y - BorderWidth) < (MinY.Value) THEN
					MinY.Value := TRUNC(SegGetInfo.SegmentInfo.StartFrame.Pos.Y - BorderWidth);
				END_IF
				IF (SegGetInfo.SegmentInfo.EndFrame.Pos.Y - BorderWidth) < (MinY.Value) THEN
					MinY.Value := TRUNC(SegGetInfo.SegmentInfo.EndFrame.Pos.Y - BorderWidth);
				END_IF
				IF (SegGetInfo.SegmentInfo.StartFrame.Pos.Y + BorderWidth) > (MaxY.Value) THEN
					MaxY.Value := TRUNC(SegGetInfo.SegmentInfo.StartFrame.Pos.Y + BorderWidth);
				END_IF
				IF (SegGetInfo.SegmentInfo.EndFrame.Pos.Y + BorderWidth) > (MaxY.Value) THEN
					MaxY.Value := TRUNC(SegGetInfo.SegmentInfo.EndFrame.Pos.Y + BorderWidth);
				END_IF
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
			GatherState := GATHER_DRAW_SEGMENTS;
			
		GATHER_DRAW_SEGMENTS:
			// Determine the width and height and then convert the INTs to strings
			ViewWidth.Value := MaxX.Value - MinX.Value;
			ViewHeight.Value := MaxY.Value - MinY.Value;
			ViewWidth.String := INT_TO_STRING(ViewWidth.Value);
			ViewHeight.String := INT_TO_STRING(ViewHeight.Value);
			// The inverse of max Y is used as the min Y because the Y axis is flipped in the svg coordinate system
			MinX.String := INT_TO_STRING(MinX.Value);
			MinY.String := INT_TO_STRING(-1 * MaxY.Value);
			// Clear the svg and write the viewbox pars (minx miny width height)
			brsmemset(ADR(AssemblySchematics.SvgContent),0,SIZEOF(AssemblySchematics.SvgContent));
			AssemblySchematics.SvgContent := '<svg viewbox="';
			AssemblySchematics.SvgContent := CONCAT(AssemblySchematics.SvgContent,MinX.String);
			AssemblySchematics.SvgContent := CONCAT(AssemblySchematics.SvgContent,' ');
			AssemblySchematics.SvgContent := CONCAT(AssemblySchematics.SvgContent,MinY.String);
			AssemblySchematics.SvgContent := CONCAT(AssemblySchematics.SvgContent,' ');
			AssemblySchematics.SvgContent := CONCAT(AssemblySchematics.SvgContent,ViewWidth.String);
			AssemblySchematics.SvgContent := CONCAT(AssemblySchematics.SvgContent,' ');
			AssemblySchematics.SvgContent := CONCAT(AssemblySchematics.SvgContent,ViewHeight.String);
			AssemblySchematics.SvgContent := CONCAT(AssemblySchematics.SvgContent,'">');
			FOR SegmentIndex:=0 TO NUM_SEGMENTS DO
				// Only draw if the entry is not empty
				IF NOT (AssemblySchematics.Segment[SegmentIndex].Name = '') THEN
					// The points are truncated to int. Values being off by less than a mm will not visibly make a difference, but it saves string character space
					// Y values are inverted because the Y axis is flipped in the svg coordinate system
					StartX.Value := TRUNC(AssemblySchematics.Segment[SegmentIndex].StartFrame.Pos.X);
					StartY.Value := -1 * TRUNC(AssemblySchematics.Segment[SegmentIndex].StartFrame.Pos.Y);
					EndX.Value := TRUNC(AssemblySchematics.Segment[SegmentIndex].EndFrame.Pos.X);
					EndY.Value := -1 * TRUNC(AssemblySchematics.Segment[SegmentIndex].EndFrame.Pos.Y);
					StartX.String := INT_TO_STRING(StartX.Value);
					StartY.String := INT_TO_STRING(StartY.Value);
					EndX.String := INT_TO_STRING(EndX.Value);
					EndY.String := INT_TO_STRING(EndY.Value);
					// Draw a line with the following syntax: 
					// <line x1="StartX" y1="StartY" x2="EndX" y2="EndY" style="stroke:rgb(0,0,0);stroke-width:10" />
					brsmemset(ADR(NewLine),0,SIZEOF(NewLine));
					NewLine := '<line x1="';
					NewLine := CONCAT(NewLine,StartX.String);
					NewLine := CONCAT(NewLine,'" y1="');
					NewLine := CONCAT(NewLine,StartY.String);
					NewLine := CONCAT(NewLine,'" x2="');
					NewLine := CONCAT(NewLine,EndX.String);
					NewLine := CONCAT(NewLine,'" y2="');
					NewLine := CONCAT(NewLine,EndY.String);
					NewLine := CONCAT(NewLine,'" style="stroke:rgb(0,0,0);stroke-width:10"/>');
					brsstrcat(ADR(AssemblySchematics.SvgContent),ADR(NewLine));
				END_IF
			END_FOR
			GatherState := GATHER_DRAW_DIVERTS;
			
		GATHER_DRAW_DIVERTS:
			FOR DivertIndex:=0 TO NUM_DIVERTS DO
				// Only draw if the entry is not empty
				IF AssemblySchematics.Diverts[DivertIndex].Overlap > 0 THEN
					// All measurments will be based on the [0] index segment, 
					// The points are truncated to int. Values being off by less than a mm will not visibly make a difference, but it saves string character space
					// Y values are inverted because the Y axis is flipped in the svg coordinate system
					RefSegID := AssemblySchematics.Diverts[DivertIndex].SegID[0];
					// The divert index will be used as the name for the rectangle
					RectName.Value := DivertIndex;
					// Decide the segment type
					CASE AssemblySchematics.Segment[RefSegID].Type OF
						mcACPTRAK_SEG_STR_660,mcACPTRAK_SEG_STR_105_TO_CIRC:
							// The segment is an AA or an AB, certain values are based on the start point
							// RectX = StartX - Midpoint - (Overlap / 2) ... Midpoint and Overlap are in meters, so multiply by 1000 for mm
							RectX.Value := TRUNC(AssemblySchematics.Segment[RefSegID].StartFrame.Pos.X - (AssemblySchematics.Diverts[DivertIndex].DivertMid[0] * 1000) - (AssemblySchematics.Diverts[DivertIndex].Overlap * 1000 / 2));
							RectY.Value := -1 * TRUNC(AssemblySchematics.Segment[RefSegID].StartFrame.Pos.Y);
							// The width is always the overlap (converted to mm) and the height is the divert distance (30mm)
							RectWidth.Value := TRUNC(AssemblySchematics.Diverts[DivertIndex].Overlap * 1000);
							RectHeight.Value := 30;
							// The rotation about X,Y is about the start point
							RectRotX.Value := TRUNC(AssemblySchematics.Segment[RefSegID].StartFrame.Pos.X);
							RectRotY.Value := -1 * TRUNC(AssemblySchematics.Segment[RefSegID].StartFrame.Pos.Y);
							// Defining the rotation angle depends on the values of angles 1 and 2
							IF AssemblySchematics.Segment[RefSegID].StartFrame.Orient.Angle1 = 0 AND AssemblySchematics.Segment[RefSegID].StartFrame.Orient.Angle2 = 180 THEN
								RectRotAngle.Value := TRUNC(ABS(AssemblySchematics.Segment[RefSegID].StartFrame.Orient.Angle3));
							ELSIF AssemblySchematics.Segment[RefSegID].StartFrame.Orient.Angle1 = 0 AND AssemblySchematics.Segment[RefSegID].StartFrame.Orient.Angle2 = -180 THEN
								RectRotAngle.Value := TRUNC(AssemblySchematics.Segment[RefSegID].StartFrame.Orient.Angle3 + 360);
							ELSIF AssemblySchematics.Segment[RefSegID].StartFrame.Orient.Angle1 = 180 AND AssemblySchematics.Segment[RefSegID].StartFrame.Orient.Angle2 = 0 THEN
								RectRotAngle.Value := TRUNC(AssemblySchematics.Segment[RefSegID].StartFrame.Orient.Angle3 + 180);
							END_IF
							
						mcACPTRAK_SEG_CIRC_TO_STR_105:
							// The segment is a BA, certain values are based on the end point
							// RectX = EndX + (450 - Midpoint) - (Overlap / 2) ... Midpoint and Overlap are in meters, so multiply by 1000 for mm
							RectX.Value := TRUNC(AssemblySchematics.Segment[RefSegID].EndFrame.Pos.X + (450 - (AssemblySchematics.Diverts[DivertIndex].DivertMid[0] * 1000)) - (AssemblySchematics.Diverts[DivertIndex].Overlap * 1000 / 2));
							RectY.Value := -1 * TRUNC(AssemblySchematics.Segment[RefSegID].EndFrame.Pos.Y);
							// The width is always the overlap (converted to mm) and the height is the divert distance (30mm)
							RectWidth.Value := TRUNC(AssemblySchematics.Diverts[DivertIndex].Overlap * 1000);
							RectHeight.Value := 30;
							// The rotation about X,Y is about the end point
							RectRotX.Value := TRUNC(AssemblySchematics.Segment[RefSegID].EndFrame.Pos.X);
							RectRotY.Value := -1 * TRUNC(AssemblySchematics.Segment[RefSegID].EndFrame.Pos.Y);
							// Defining the rotation angle depends on the values of angles 1 and 2
							IF AssemblySchematics.Segment[RefSegID].EndFrame.Orient.Angle1 = 0 AND AssemblySchematics.Segment[RefSegID].EndFrame.Orient.Angle2 = 180 THEN
								RectRotAngle.Value := TRUNC(ABS(AssemblySchematics.Segment[RefSegID].EndFrame.Orient.Angle3));
							ELSIF AssemblySchematics.Segment[RefSegID].EndFrame.Orient.Angle1 = 0 AND AssemblySchematics.Segment[RefSegID].EndFrame.Orient.Angle2 = -180 THEN
								RectRotAngle.Value := TRUNC(AssemblySchematics.Segment[RefSegID].EndFrame.Orient.Angle3 + 360);
							ELSIF AssemblySchematics.Segment[RefSegID].EndFrame.Orient.Angle1 = 180 AND AssemblySchematics.Segment[RefSegID].EndFrame.Orient.Angle2 = 0 THEN
								RectRotAngle.Value := TRUNC(AssemblySchematics.Segment[RefSegID].EndFrame.Orient.Angle3 + 180);
							END_IF
						
					END_CASE
					// Convert the values to strings
					RectName.String := INT_TO_STRING(RectName.Value);
					RectX.String := INT_TO_STRING(RectX.Value);
					RectY.String := INT_TO_STRING(RectY.Value);
					RectWidth.String := INT_TO_STRING(RectWidth.Value);
					RectHeight.String := INT_TO_STRING(RectHeight.Value);
					RectRotAngle.String := INT_TO_STRING(RectRotAngle.Value);
					RectRotX.String := INT_TO_STRING(RectRotX.Value);
					RectRotY.String := INT_TO_STRING(RectRotY.Value);
					// Draw the rectangle with the following syntax
					// <rect x="RectX" y="RectY" width="RectWidth" height="RectHeight" fill="rgb(255,0,0)" transform="rotate(RectRotAngle RectRotX RectRotY)"/>
					brsmemset(ADR(NewLine),0,SIZEOF(NewLine));
					NewLine := '<rect id="Div_';
					NewLine := CONCAT(NewLine,RectName.String);
					NewLine := CONCAT(NewLine,'" x="');
					NewLine := CONCAT(NewLine,RectX.String);
					NewLine := CONCAT(NewLine,'" y="');
					NewLine := CONCAT(NewLine,RectY.String);
					NewLine := CONCAT(NewLine,'" width="');
					NewLine := CONCAT(NewLine,RectWidth.String);
					NewLine := CONCAT(NewLine,'" height="');
					NewLine := CONCAT(NewLine,RectHeight.String);
					NewLine := CONCAT(NewLine,'" fill="rgb(33,118,174)" transform="rotate(');
					NewLine := CONCAT(NewLine,RectRotAngle.String);
					NewLine := CONCAT(NewLine,' ');
					NewLine := CONCAT(NewLine,RectRotX.String);
					NewLine := CONCAT(NewLine,' ');
					NewLine := CONCAT(NewLine,RectRotY.String);
					NewLine := CONCAT(NewLine,')"/>');
					brsstrcat(ADR(AssemblySchematics.SvgContent),ADR(NewLine));					
				END_IF
			END_FOR
			// Write the footer line
			brsmemset(ADR(NewLine),0,SIZEOF(NewLine));
			NewLine := '</svg>';
			brsstrcat(ADR(AssemblySchematics.SvgContent),ADR(NewLine));
			GatherState := GATHER_SHUTTLE;
			
		GATHER_SHUTTLE:
			// Get the reference of the shuttle on the trak
			AsmGetShuttle.Enable := TRUE;
			IF AsmGetShuttle.Valid THEN
				AxisReference := AsmGetShuttle.Axis;
				AsmGetShuttle.Enable := FALSE;
				RoutedMoveAbs.Axis := ADR(AxisReference);
				ShReadInfo.Axis := ADR(AxisReference);
				ShReadInfo.Enable := TRUE;
				ShReadSeg.Axis := ADR(AxisReference);
				ShReadSeg.Enable := TRUE;
				GatherState := GATHER_MOVE_TO_START;
			END_IF
		
		GATHER_MOVE_TO_START:
			// ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! !
			// ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! !
			// ! ! !           MAKE SHUTTLE CHANGE COLOR WHEN DIVERT FOUND           ! ! !
			// ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! !
			// ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! !
			
			// Move to the start of the sector at full speed
			RoutedMoveAbs.Sector := ADR(AssemblySchematics.Sectors[SectorIndex].Reference);
			RoutedMoveAbs.Axis := ADR(AxisReference);
			RoutedMoveAbs.Position := 0;
			RoutedMoveAbs.Velocity := TestVelocity;
			RoutedMoveAbs.Acceleration := 50;
			RoutedMoveAbs.Deceleration := 50;
			RoutedMoveAbs.AdvancedParameters.StartDirection := mcDIR_UNDEFINED;
			RoutedMoveAbs.AdvancedParameters.EndDirection := mcDIR_UNDEFINED;
			RoutedMoveAbs.AdvancedParameters.ShuttleOrientation := mcDIR_UNDEFINED;
			RoutedMoveAbs.Execute := TRUE;
			MovingToSec := TRUE;
			IF RoutedMoveAbs.Active THEN
				GatherState := GATHER_MONITOR_FOR_MIDPOINT;
			END_IF
				
		GATHER_MOVE_ALONG_SEC:
			// Move to the end of the sector in the positive direction
			ElasticMoveAbs.Axis := ADR(AxisReference);
			ElasticMoveAbs.Position := AssemblySchematics.Sectors[SectorIndex].Length;
			ElasticMoveAbs.Velocity := TestVelocity;
			ElasticMoveAbs.Acceleration := 50;
			ElasticMoveAbs.Deceleration := 50;
			ElasticMoveAbs.Execute := TRUE;
			MovingOnSec := TRUE;
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
							RoutedMoveAbs.Execute := FALSE;
							AsmStop.Execute := TRUE;
							// Set the transform such that the divert turns orange immediately
							RectName.Value := DivertIndex;
							RectName.String := INT_TO_STRING(RectName.Value);
							brsmemset(ADR(AssemblySchematics.SvgTransform),0,SIZEOF(AssemblySchematics.SvgTransform));
							brsmemset(ADR(NewLine),0,SIZEOF(NewLine));
							NewLine := '[{"select":"#Div_';
							NewLine := CONCAT(NewLine,RectName.String);
							NewLine := CONCAT(NewLine,'","fill":1,"duration":0}]');
							brsstrcat(ADR(AssemblySchematics.SvgTransform),ADR(NewLine));
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
							RoutedMoveAbs.Execute := FALSE;
							AsmStop.Execute := TRUE;
							// Set the transform such that the divert turns orange immediately
							RectName.Value := DivertIndex;
							RectName.String := INT_TO_STRING(RectName.Value);
							brsmemset(ADR(AssemblySchematics.SvgTransform),0,SIZEOF(AssemblySchematics.SvgTransform));
							brsmemset(ADR(NewLine),0,SIZEOF(NewLine));
							NewLine := '[{"select":"#Div_';
							NewLine := CONCAT(NewLine,RectName.String);
							NewLine := CONCAT(NewLine,'","fill":1,"duration":0}]');
							brsstrcat(ADR(AssemblySchematics.SvgTransform),ADR(NewLine));
							GatherState := GATHER_ACKNOWLEDGE;
							EXIT;
						END_IF
					END_IF
				END_IF
			END_FOR
			// If the move finishes, the shuttle reached the end of the sector. Increment the sector index
			IF ElasticMoveAbs.Done THEN
				MovingOnSec := FALSE;
				ElasticMoveAbs.Execute := FALSE;
				SectorIndex := SectorIndex + 1;
				// if the index is less than or equal to the limit, check that it is not an empty entry
				IF SectorIndex <= NUM_SECTORS THEN
					// If the entry is not empty, go to the start of that sector
					IF AssemblySchematics.Sectors[SectorIndex].Length <> 0 THEN
						GatherState := GATHER_MOVE_TO_START;
					// If the entry is empty, all sectors have been checked but all diverts were not found
					ELSE
						ErrorMessage := 'Some diverts could not be found. Make sure all diverts have sectors through them.';
						GatherState := GATHER_ERROR;
					END_IF
				// If the index is greater than the limit, all entries have been checked but all diverts were not found
				ELSE
					ErrorMessage := 'Some diverts could not be found. Make sure all diverts have sectors through them.';
					GatherState := GATHER_ERROR;
				END_IF
			END_IF
			IF RoutedMoveAbs.Done THEN
				MovingToSec := FALSE;
				RoutedMoveAbs.Execute := FALSE;
				GatherState := GATHER_MOVE_ALONG_SEC;
			END_IF
		
		GATHER_ACKNOWLEDGE:
			// When the command is given, go back to moving along the sector
			IF AsmStop.Done THEN
				AsmStop.Execute := FALSE;
				AcknowledgeTimer.PT := AcknowledgeTime;
				AcknowledgeTimer.IN := TRUE;
			END_IF
			IF AcknowledgeTimer.Q THEN
				AcknowledgeTimer.IN := FALSE;
				// Clear the flag before checking
				MoreDivertsToFind := FALSE;
				// Check if there are anymore diverts to find
				FOR DivertIndex:=0 TO NUM_DIVERTS DO
					// If both segment IDs for a divert are non-zero and the divert has not been measured then more diverts need to be found
					IF (AssemblySchematics.Diverts[DivertIndex].SegID[0] <> 0) AND (AssemblySchematics.Diverts[DivertIndex].SegID[1] <> 0) AND NOT AssemblySchematics.Diverts[DivertIndex].Measured THEN
						MoreDivertsToFind := TRUE;
						EXIT;
					END_IF
				END_FOR
				// If there are more diverts to find, then move appropriately
				IF MoreDivertsToFind THEN
					// If the shuttle stopped along the way to a sector, re-initiate the routed move
					IF MovingToSec THEN
						GatherState := GATHER_MOVE_TO_START;
					// If the shuttle stopped while moving on a sector, re-initiate the elastic move
					ELSIF MovingOnSec THEN
						GatherState := GATHER_MOVE_ALONG_SEC;
					// If the shuttle is no longer moving to the sector or on the sector, then start the next routed move
					ELSE
						GatherState := GATHER_MOVE_TO_START;					
					END_IF
				ELSE
					// If there are no more diverts to find then the gathering is done
					GatherState := GATHER_DONE;
				END_IF
			END_IF
		
		GATHER_DONE:
			// Clear everything and wait for the reset of the gather command
			DivertIndex := 0;
			SectorIndex := 0;
			MovingToSec := FALSE;
			MovingOnSec := FALSE;
			brsmemset(ADR(AxisReference),0,SIZEOF(AxisReference));
			IF NOT CmdGather THEN
				GatherState := GATHER_IDLE;
			END_IF
		
		GATHER_ERROR:
			// Wait for the reset of the gather command
			IF NOT CmdGather THEN
				// Clear everything before returning to idle
				DivertIndex := 0;
				SectorIndex := 0;
				MovingToSec := FALSE;
				MovingOnSec := FALSE;
				brsmemset(ADR(AxisReference),0,SIZEOF(AxisReference));
				brsmemset(ADR(ErrorMessage),0,SIZEOF(ErrorMessage));				
				GatherState := GATHER_IDLE;
			END_IF
			
				
	END_CASE
			
	AsmGetSeg();
	AsmGetSec();
	AsmStop();
	SegGetInfo();
	SecGetInfo();
	AsmGetShuttle();
	RoutedMoveAbs();
	ElasticMoveAbs();
	ShReadInfo();
	ShReadSeg();
	AcknowledgeTimer();
	
END_PROGRAM
