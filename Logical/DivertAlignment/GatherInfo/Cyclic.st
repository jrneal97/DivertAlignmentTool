
PROGRAM _CYCLIC
	(* Insert code here *)
	CASE GatherState OF
		GATHER_IDLE:
			// Wait for command, then clear the schematic structure and pass in the assembly reference
			IF CmdGather THEN
				brsmemset(ADR(AssemblySchematics),0,SIZEOF(AssemblySchematics));
				AssemblySchematics.AsmReference := gAssembly_1;
				GatherSegs.Schematic := ADR(AssemblySchematics);
				GatherSegs.Execute := TRUE;
				GatherSecs.Schematic := ADR(AssemblySchematics);
				GatherSecs.Execute := TRUE;
				GatherState := GATHER_SEG_AND_SEC;
			END_IF
				
		GATHER_SEG_AND_SEC:
			// Wait for the FUBs to finish
			IF GatherSegs.Done AND GatherSecs.Done THEN
				GatherSegs.Execute := FALSE;
				GatherSecs.Execute := FALSE;
				GatherState := GATHER_DIVERTS;
			END_IF
			
		GATHER_DIVERTS:
			// Use the CheckForDiverts function
			CheckForDiverts(ADR(AssemblySchematics));
			GatherState := GATHER_DRAW_SEGMENTS;
			
		GATHER_DRAW_SEGMENTS:
			// Determine the width and height and then convert the INTs to strings
			AssemblySchematics.Svg.Viewbox.Width.Value := AssemblySchematics.Svg.Viewbox.MaxX.Value - AssemblySchematics.Svg.Viewbox.MinX.Value;
			AssemblySchematics.Svg.Viewbox.Height.Value := AssemblySchematics.Svg.Viewbox.MaxY.Value - AssemblySchematics.Svg.Viewbox.MinY.Value;
			AssemblySchematics.Svg.Viewbox.Width.String := INT_TO_STRING(AssemblySchematics.Svg.Viewbox.Width.Value);
			AssemblySchematics.Svg.Viewbox.Height.String := INT_TO_STRING(AssemblySchematics.Svg.Viewbox.Height.Value);
			// The inverse of max Y is used as the min Y because the Y axis is flipped in the svg coordinate system
			AssemblySchematics.Svg.Viewbox.MinX.String := INT_TO_STRING(AssemblySchematics.Svg.Viewbox.MinX.Value);
			AssemblySchematics.Svg.Viewbox.MinY.String := INT_TO_STRING(-1 * AssemblySchematics.Svg.Viewbox.MaxY.Value);
			// Clear the svg and write the viewbox pars (minx miny width height)
			brsmemset(ADR(AssemblySchematics.Svg.Content),0,SIZEOF(AssemblySchematics.Svg.Content));
			AssemblySchematics.Svg.Content := '<svg viewbox="';
			AssemblySchematics.Svg.Content := CONCAT(AssemblySchematics.Svg.Content,AssemblySchematics.Svg.Viewbox.MinX.String);
			AssemblySchematics.Svg.Content := CONCAT(AssemblySchematics.Svg.Content,' ');
			AssemblySchematics.Svg.Content := CONCAT(AssemblySchematics.Svg.Content,AssemblySchematics.Svg.Viewbox.MinY.String);
			AssemblySchematics.Svg.Content := CONCAT(AssemblySchematics.Svg.Content,' ');
			AssemblySchematics.Svg.Content := CONCAT(AssemblySchematics.Svg.Content,AssemblySchematics.Svg.Viewbox.Width.String);
			AssemblySchematics.Svg.Content := CONCAT(AssemblySchematics.Svg.Content,' ');
			AssemblySchematics.Svg.Content := CONCAT(AssemblySchematics.Svg.Content,AssemblySchematics.Svg.Viewbox.Height.String);
			AssemblySchematics.Svg.Content := CONCAT(AssemblySchematics.Svg.Content,'">');
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
					brsstrcat(ADR(AssemblySchematics.Svg.Content),ADR(NewLine));
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
					NewLine := CONCAT(NewLine,'" fill="rgb(198,198,198)" transform="rotate(');
					NewLine := CONCAT(NewLine,RectRotAngle.String);
					NewLine := CONCAT(NewLine,' ');
					NewLine := CONCAT(NewLine,RectRotX.String);
					NewLine := CONCAT(NewLine,' ');
					NewLine := CONCAT(NewLine,RectRotY.String);
					NewLine := CONCAT(NewLine,')"/>');
					brsstrcat(ADR(AssemblySchematics.Svg.Content),ADR(NewLine));					
				END_IF
			END_FOR
			// Write the footer line
			brsmemset(ADR(NewLine),0,SIZEOF(NewLine));
			NewLine := '</svg>';
			brsstrcat(ADR(AssemblySchematics.Svg.Content),ADR(NewLine));
			GatherState := GATHER_MOVE_VIRTUALS;
		
		GATHER_MOVE_VIRTUALS:
			// Interate through all sectors and set the virtual shuttles in motion to the end of their sectors
			FOR VirtualIndex:=0 TO NUM_SECTORS DO
				// Only operate on indeces with sector references in them
				IF AssemblySchematics.Sectors[VirtualIndex].Reference.controlif <> 0 THEN
					VirtualShReadInfo[VirtualIndex].Axis := ADR(AssemblySchematics.VirtualShuttles[VirtualIndex]);
					VirtualShReadInfo[VirtualIndex].Enable := TRUE;
					VirtualElasticMoveAbs[VirtualIndex].Axis := ADR(AssemblySchematics.VirtualShuttles[VirtualIndex]);
					VirtualElasticMoveAbs[VirtualIndex].Position := AssemblySchematics.Sectors[VirtualIndex].Length;
					VirtualElasticMoveAbs[VirtualIndex].Velocity := VirtualMotionPars.Velocity;
					VirtualElasticMoveAbs[VirtualIndex].Acceleration := VirtualMotionPars.Accel;
					VirtualElasticMoveAbs[VirtualIndex].Deceleration := VirtualMotionPars.Decel;
					VirtualElasticMoveAbs[VirtualIndex].Execute := TRUE;
				END_IF
			END_FOR
			GatherState := GATHER_SCAN_SECTORS;
			
		GATHER_SCAN_SECTORS:
			// Check every virtual shuttle
			FOR VirtualIndex:=0 TO NUM_SECTORS DO
				// Only check shuttles still in motion
				IF VirtualElasticMoveAbs[VirtualIndex].Execute AND NOT VirtualElasticMoveAbs[VirtualIndex].Done THEN
					// Constantly compare the current seg position to the divert seg midpoints. Only check divert entries that aren't empty and haven't been found yet
					FOR DivertIndex:=0 TO NUM_DIVERTS DO
						IF (AssemblySchematics.Diverts[DivertIndex].Overlap <> 0) AND NOT AssemblySchematics.Diverts[DivertIndex].Found THEN
							// If the shuttle is on the same segment as the divert's first segment then compare the positions
							IF (VirtualShReadInfo[VirtualIndex].ShuttleInfo.CurrentValues.SegmentPosition.Name = AssemblySchematics.Diverts[DivertIndex].SegName[0]) THEN
								// If the shuttles current position on the segment is within DIV_MIDPOINT_TOLERANCE of the midpoint then stop and take the measurement
								IF (VirtualShReadInfo[VirtualIndex].ShuttleInfo.CurrentValues.SegmentPosition.Position > AssemblySchematics.Diverts[DivertIndex].DivertMid[0] - DIV_MIDPOINT_TOLERANCE) AND
									(VirtualShReadInfo[VirtualIndex].ShuttleInfo.CurrentValues.SegmentPosition.Position < AssemblySchematics.Diverts[DivertIndex].DivertMid[0] + DIV_MIDPOINT_TOLERANCE) THEN
									// Record the sector and position for the divert
									AssemblySchematics.Diverts[DivertIndex].Found := TRUE;
									AssemblySchematics.Diverts[DivertIndex].SecRef[0] := VirtualShReadInfo[VirtualIndex].ShuttleInfo.CurrentValues.Sector;
									AssemblySchematics.Diverts[DivertIndex].SecName[0] := VirtualShReadInfo[VirtualIndex].ShuttleInfo.CurrentValues.SectorName;
									AssemblySchematics.Diverts[DivertIndex].PosOnSec[0] := VirtualShReadInfo[VirtualIndex].ShuttleInfo.CurrentValues.Position;
								END_IF
								// If the shuttle is on the same segment as the divert's second segment then compare the positions
							ELSIF (ShReadInfo.ShuttleInfo.CurrentValues.SegmentPosition.Name = AssemblySchematics.Diverts[DivertIndex].SegName[1]) THEN
								// If the shuttles current position on the segment is within DIV_MIDPOINT_TOLERANCE of the midpoint then stop and take the measurement
								IF (VirtualShReadInfo[VirtualIndex].ShuttleInfo.CurrentValues.SegmentPosition.Position > AssemblySchematics.Diverts[DivertIndex].DivertMid[1] - DIV_MIDPOINT_TOLERANCE) AND
									(VirtualShReadInfo[VirtualIndex].ShuttleInfo.CurrentValues.SegmentPosition.Position < AssemblySchematics.Diverts[DivertIndex].DivertMid[1] + DIV_MIDPOINT_TOLERANCE) THEN
									// Record the sector and position for the divert
									AssemblySchematics.Diverts[DivertIndex].Found := TRUE;
									AssemblySchematics.Diverts[DivertIndex].SecRef[1] := VirtualShReadInfo[VirtualIndex].ShuttleInfo.CurrentValues.Sector;
									AssemblySchematics.Diverts[DivertIndex].SecName[1] := VirtualShReadInfo[VirtualIndex].ShuttleInfo.CurrentValues.SectorName;
									AssemblySchematics.Diverts[DivertIndex].PosOnSec[1] := VirtualShReadInfo[VirtualIndex].ShuttleInfo.CurrentValues.Position;
								END_IF
							END_IF
						END_IF
					END_FOR
				END_IF
			END_FOR
			// Write the color of the diverts every cycle
			WriteDivertTransform(ADR(AssemblySchematics));
			// Clear the flags
			MoreDivertsToFind := FALSE;
			VirtualShuttlesInMotion := FALSE;
			// Check if there are more diverts to find
			FOR DivertIndex:=0 TO NUM_DIVERTS DO
				// If the entry's overlap is non-zero and a divert hasn't been found keep going
				IF (AssemblySchematics.Diverts[DivertIndex].Overlap <> 0) AND NOT AssemblySchematics.Diverts[DivertIndex].Found THEN
					MoreDivertsToFind := TRUE;
					EXIT;
				END_IF
			END_FOR
			// Check if virtual shuttles are still moving
			FOR VirtualIndex:=0 TO NUM_SECTORS DO
				// If the movement FUB is executed but not done, then a shuttle is still in motion
				IF VirtualElasticMoveAbs[VirtualIndex].Execute AND NOT VirtualElasticMoveAbs[VirtualIndex].Done THEN
					VirtualShuttlesInMotion := TRUE;
					EXIT;
				END_IF
			END_FOR
			// Decide how to proceed
			IF MoreDivertsToFind AND VirtualShuttlesInMotion THEN
				// There are diverts left to find and shuttles are still in motion. All is fine
				(* Stay in the state *)
			ELSIF NOT MoreDivertsToFind AND VirtualShuttlesInMotion THEN
				// All diverts have been found, but shuttles are still in motion. Stop them, then proceed to deleting them
				AsmStop.Execute := TRUE;
				GatherState := GATHER_DELETE_VIRTUALS;
			ELSIF MoreDivertsToFind AND NOT VirtualShuttlesInMotion THEN
				// There are diverts left to find, but the shuttles have reached the end of their sectors. Raise an alarm
				ErrorMessage := 'Some diverts could not be found. Make sure all diverts have sectors through them.';
				GatherState := GATHER_ERROR;
			END_IF
			
		GATHER_DELETE_VIRTUALS:
			// Delete all virtual shuttles
			AsmDeleteVirtualSh.Execute := TRUE;
			IF AsmDeleteVirtualSh.Done THEN
				AsmDeleteVirtualSh.Execute := FALSE;
				(*Start moving real shuttle*)
			END_IF
			
		GATHER_SHUTTLE:
			// Get the reference of the real (non-virtual) shuttle on the trak
			AsmGetShuttleSel.AdvancedParameters.VirtualSelectionMode := mcACPTRAK_GET_SH_VIRT_NONVIRTUAL;
			AsmGetShuttleSel.Enable := TRUE;
			IF AsmGetShuttleSel.Valid THEN
				AxisReference := AsmGetShuttleSel.Axis;
				AsmGetShuttleSel.Enable := FALSE;
				RoutedMoveAbs.Axis := ADR(AxisReference);
				ShReadInfo.Axis := ADR(AxisReference);
				ShReadInfo.Enable := TRUE;
				ShReadSeg.Axis := ADR(AxisReference);
				ShReadSeg.Enable := TRUE;
				GatherState := GATHER_MOVE_TO_START;
			END_IF
		
		GATHER_MOVE_TO_START:			
			// Move to the start of the sector at full speed
			RoutedMoveAbs.Sector := ADR(AssemblySchematics.Sectors[SectorIndex].Reference);
			RoutedMoveAbs.Axis := ADR(AxisReference);
			RoutedMoveAbs.Position := 0;
			RoutedMoveAbs.Velocity := PhysicalMotionPars.Velocity;
			RoutedMoveAbs.Acceleration := PhysicalMotionPars.Accel;
			RoutedMoveAbs.Deceleration := PhysicalMotionPars.Decel;
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
			ElasticMoveAbs.Velocity := PhysicalMotionPars.Velocity;
			ElasticMoveAbs.Acceleration := PhysicalMotionPars.Accel;
			ElasticMoveAbs.Deceleration := PhysicalMotionPars.Decel;
			ElasticMoveAbs.Execute := TRUE;
			MovingOnSec := TRUE;
			IF ElasticMoveAbs.Active THEN
				GatherState := GATHER_MONITOR_FOR_MIDPOINT;
			END_IF
			
		GATHER_MONITOR_FOR_MIDPOINT:
			// Constantly compare the current seg position to the divert seg midpoints
			// Execute a stop if within DIV_MIDPOINT_TOLERANCE of one
			FOR DivertIndex:=0 TO NUM_DIVERTS DO
				IF NOT AssemblySchematics.Diverts[DivertIndex].Measurements.Measured THEN
					// If the shuttle is on the same segment as the divert's first segment then compare the positions
					IF (ShReadInfo.ShuttleInfo.CurrentValues.SegmentPosition.Name = AssemblySchematics.Diverts[DivertIndex].SegName[0]) THEN
						// If the shuttles current position on the segment is within DIV_MIDPOINT_TOLERANCE of the midpoint then stop and take the measurement
						IF (ShReadInfo.ShuttleInfo.CurrentValues.SegmentPosition.Position > AssemblySchematics.Diverts[DivertIndex].DivertMid[0] - DIV_MIDPOINT_TOLERANCE) AND
							(ShReadInfo.ShuttleInfo.CurrentValues.SegmentPosition.Position < AssemblySchematics.Diverts[DivertIndex].DivertMid[0] + DIV_MIDPOINT_TOLERANCE) THEN
							// Take measurements in the divert
							MeasureDivert(ADR(AssemblySchematics),ShReadSeg.SegmentInfo,DivertIndex);
							ElasticMoveAbs.Execute := FALSE;
							RoutedMoveAbs.Execute := FALSE;
							AsmStop.Execute := TRUE;
							// Set the transform such that the divert turns orange immediately
							RectName.Value := DivertIndex;
							RectName.String := INT_TO_STRING(RectName.Value);
							brsmemset(ADR(AssemblySchematics.Svg.Transform),0,SIZEOF(AssemblySchematics.Svg.Transform));
							brsmemset(ADR(NewLine),0,SIZEOF(NewLine));
							NewLine := '[{"select":"#Div_';
							NewLine := CONCAT(NewLine,RectName.String);
							NewLine := CONCAT(NewLine,'","fill":2,"duration":0}]');
							brsstrcat(ADR(AssemblySchematics.Svg.Transform),ADR(NewLine));
							GatherState := GATHER_ACKNOWLEDGE;
							EXIT;
						END_IF
					// If the shuttle is on the same segment as the divert's second segment then compare the positions
					ELSIF (ShReadInfo.ShuttleInfo.CurrentValues.SegmentPosition.Name = AssemblySchematics.Diverts[DivertIndex].SegName[1]) THEN
						// If the shuttles current position on the segment is within DIV_MIDPOINT_TOLERANCE of the midpoint then stop and take the measurement
						IF (ShReadInfo.ShuttleInfo.CurrentValues.SegmentPosition.Position > AssemblySchematics.Diverts[DivertIndex].DivertMid[1] - DIV_MIDPOINT_TOLERANCE) AND
							(ShReadInfo.ShuttleInfo.CurrentValues.SegmentPosition.Position < AssemblySchematics.Diverts[DivertIndex].DivertMid[1] + DIV_MIDPOINT_TOLERANCE) THEN
							// Take measurements in the divert
							MeasureDivert(ADR(AssemblySchematics),ShReadSeg.SegmentInfo,DivertIndex);
							ElasticMoveAbs.Execute := FALSE;
							RoutedMoveAbs.Execute := FALSE;
							AsmStop.Execute := TRUE;
							// Set the transform such that the divert turns orange immediately
							RectName.Value := DivertIndex;
							RectName.String := INT_TO_STRING(RectName.Value);
							brsmemset(ADR(AssemblySchematics.Svg.Transform),0,SIZEOF(AssemblySchematics.Svg.Transform));
							brsmemset(ADR(NewLine),0,SIZEOF(NewLine));
							NewLine := '[{"select":"#Div_';
							NewLine := CONCAT(NewLine,RectName.String);
							NewLine := CONCAT(NewLine,'","fill":2,"duration":0}]');
							brsstrcat(ADR(AssemblySchematics.Svg.Transform),ADR(NewLine));
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
					IF (AssemblySchematics.Diverts[DivertIndex].SegID[0] <> 0) AND (AssemblySchematics.Diverts[DivertIndex].SegID[1] <> 0) AND NOT AssemblySchematics.Diverts[DivertIndex].Measurements.Measured THEN
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
	
	// Call FUBs
	GatherSegs();
	GatherSecs();
	AsmStop();
	AsmDeleteVirtualSh();
	AsmGetShuttleSel();
	RoutedMoveAbs();
	ElasticMoveAbs();
	ShReadInfo();
	ShReadSeg();
	AcknowledgeTimer();
	FOR VirtualIndex:=0 TO NUM_SECTORS DO
		// Only call FUBs corresponding to sector entries with sector references in them
		IF AssemblySchematics.Sectors[VirtualIndex].Reference.controlif <> 0 THEN
			VirtualShReadInfo[VirtualIndex]();
			VirtualElasticMoveAbs[VirtualIndex]();
		END_IF
	END_FOR
	
	
END_PROGRAM
