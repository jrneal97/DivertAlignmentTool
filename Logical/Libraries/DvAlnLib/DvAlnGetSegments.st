(*********************************************************************************
 * Copyright: B&R Industrial Automation GmbH 
 * Author:    nealj 
 * Created:   November 30, 2023/10:41 AM 
 * 
 *********************************************************************************)

FUNCTION_BLOCK DvAlnGetSegments
			
	CASE Internal.State OF
		
		GET_SEG_IDLE:
			// Wait for execute, enable the AsmGetSeg FUB
			IF Execute THEN
				Internal.AsmGetSeg.Assembly := ADR(Schematic.AsmReference);
				Internal.AsmGetSeg.Enable := TRUE;
				Schematic.Svg.Viewbox.MinX.Value := 0;
				Schematic.Svg.Viewbox.MaxX.Value := 0;
				Schematic.Svg.Viewbox.MinY.Value := 0;
				Schematic.Svg.Viewbox.MaxY.Value := 0;
				Internal.State := GET_SEG_REF;
			END_IF
					
		GET_SEG_REF:
			// Wait for validity
			IF Internal.AsmGetSeg.Valid THEN
				Internal.AsmGetSeg.Next := FALSE;
				Internal.SegGetInfo.Segment := ADR(Internal.AsmGetSeg.Segment);
				Internal.SegGetInfo.Execute := TRUE;
				Internal.State := GET_SEG_INFO;
			END_IF
				
		GET_SEG_INFO:
			// Wait for the SegGetInfo FUB to finish
			IF Internal.SegGetInfo.Done THEN
				// Record the segment information (use the segment ID as the index)
				Schematic.Segment[Internal.SegGetInfo.SegmentInfo.ID].Reference := Internal.AsmGetSeg.Segment;
				Schematic.Segment[Internal.SegGetInfo.SegmentInfo.ID].Name := Internal.SegGetInfo.SegmentInfo.Name;
				Schematic.Segment[Internal.SegGetInfo.SegmentInfo.ID].ID := Internal.SegGetInfo.SegmentInfo.ID;
				Schematic.Segment[Internal.SegGetInfo.SegmentInfo.ID].Type := Internal.SegGetInfo.SegmentInfo.Type;
				Schematic.Segment[Internal.SegGetInfo.SegmentInfo.ID].StartFrame := Internal.SegGetInfo.SegmentInfo.StartFrame;
				Schematic.Segment[Internal.SegGetInfo.SegmentInfo.ID].EndFrame := Internal.SegGetInfo.SegmentInfo.EndFrame;
				// Record the min and max values for the X values
				IF (Internal.SegGetInfo.SegmentInfo.StartFrame.Pos.X - Schematic.Svg.Viewbox.BorderWidth) < (Schematic.Svg.Viewbox.MinX.Value) THEN
					Schematic.Svg.Viewbox.MinX.Value := TRUNC(Internal.SegGetInfo.SegmentInfo.StartFrame.Pos.X - Schematic.Svg.Viewbox.BorderWidth);
				END_IF
				IF (Internal.SegGetInfo.SegmentInfo.EndFrame.Pos.X - Schematic.Svg.Viewbox.BorderWidth) < (Schematic.Svg.Viewbox.MinX.Value) THEN
					Schematic.Svg.Viewbox.MinX.Value := TRUNC(Internal.SegGetInfo.SegmentInfo.EndFrame.Pos.X - Schematic.Svg.Viewbox.BorderWidth);
				END_IF
				IF (Internal.SegGetInfo.SegmentInfo.StartFrame.Pos.X + Schematic.Svg.Viewbox.BorderWidth) > (Schematic.Svg.Viewbox.MaxX.Value) THEN
					Schematic.Svg.Viewbox.MaxX.Value := TRUNC(Internal.SegGetInfo.SegmentInfo.StartFrame.Pos.X + Schematic.Svg.Viewbox.BorderWidth);
				END_IF
				IF (Internal.SegGetInfo.SegmentInfo.EndFrame.Pos.X + Schematic.Svg.Viewbox.BorderWidth) > (Schematic.Svg.Viewbox.MaxX.Value) THEN
					Schematic.Svg.Viewbox.MaxX.Value := TRUNC(Internal.SegGetInfo.SegmentInfo.EndFrame.Pos.X + Schematic.Svg.Viewbox.BorderWidth);
				END_IF
				// Record the min and max values for the Y values
				IF (Internal.SegGetInfo.SegmentInfo.StartFrame.Pos.Y - Schematic.Svg.Viewbox.BorderWidth) < (Schematic.Svg.Viewbox.MinY.Value) THEN
					Schematic.Svg.Viewbox.MinY.Value := TRUNC(Internal.SegGetInfo.SegmentInfo.StartFrame.Pos.Y - Schematic.Svg.Viewbox.BorderWidth);
				END_IF
				IF (Internal.SegGetInfo.SegmentInfo.EndFrame.Pos.Y - Schematic.Svg.Viewbox.BorderWidth) < (Schematic.Svg.Viewbox.MinY.Value) THEN
					Schematic.Svg.Viewbox.MinY.Value := TRUNC(Internal.SegGetInfo.SegmentInfo.EndFrame.Pos.Y - Schematic.Svg.Viewbox.BorderWidth);
				END_IF
				IF (Internal.SegGetInfo.SegmentInfo.StartFrame.Pos.Y + Schematic.Svg.Viewbox.BorderWidth) > (Schematic.Svg.Viewbox.MaxY.Value) THEN
					Schematic.Svg.Viewbox.MaxY.Value := TRUNC(Internal.SegGetInfo.SegmentInfo.StartFrame.Pos.Y + Schematic.Svg.Viewbox.BorderWidth);
				END_IF
				IF (Internal.SegGetInfo.SegmentInfo.EndFrame.Pos.Y + Schematic.Svg.Viewbox.BorderWidth) > (Schematic.Svg.Viewbox.MaxY.Value) THEN
					Schematic.Svg.Viewbox.MaxY.Value := TRUNC(Internal.SegGetInfo.SegmentInfo.EndFrame.Pos.Y + Schematic.Svg.Viewbox.BorderWidth);
				END_IF
				// Reset the execute command
				Internal.SegGetInfo.Execute := FALSE;
				// If there are more segments, iterate
				IF Internal.AsmGetSeg.RemainingCount > 0 THEN
					Internal.AsmGetSeg.Next := TRUE;
					Internal.State := GET_SEG_REF;
				ELSE
					Internal.AsmGetSeg.Enable := FALSE;
					Internal.State := GET_SEG_DONE;
				END_IF
			END_IF
		
		GET_SEG_DONE:
			Done := TRUE;
			IF NOT Execute THEN
				Done := FALSE;
				Internal.State := GET_SEG_IDLE;
			END_IF
			
	END_CASE
	
	
	// Call FUBs
	Internal.AsmGetSeg();
	Internal.SegGetInfo();
	
END_FUNCTION_BLOCK