(*********************************************************************************
 * Copyright: B&R Industrial Automation GmbH 
 * Author:    nealj 
 * Created:   August 16, 2023/11:35 AM 
 * 
 *********************************************************************************)

FUNCTION CheckForDiverts
			
	// Nested for loop. For every mainindex, compare the subindex to it
	FOR MainIndex:=0 TO NUM_SEGMENTS DO
		FOR SubIndex:=0 TO NUM_SEGMENTS DO
			// If the indeces are equal, then the segment would be compared to itself, skip
			IF MainIndex = SubIndex THEN
				(* DO NOTHING *)
			// If the indeces are not equal, then proceed with the comparison
			ELSE
				// ==============================================
				// =   DECIDE HOW TO COMPARE THE TWO SEGMENTS   =
				// ==============================================
				// Based on the type of segments that are input, decide how the two should be compared and which one should be the reference
				CASE Schematic.Segment[MainIndex].Type OF
					
					mcACPTRAK_SEG_CIRC:
						// The main segment is a BB, so this cannot be a divert
						ReferenceMode := REFERENCE_NOT_NEEDED;
						ComparisonMode := CANNOT_BE_DIVERT;
			
					mcACPTRAK_SEG_STR_660:
						// The main segment is an AA, check what the sub segment is
						IF Schematic.Segment[SubIndex].Type = mcACPTRAK_SEG_CIRC THEN
							// The sub segment is a BB, so this cannot be a divert
							ReferenceMode := REFERENCE_NOT_NEEDED;
							ComparisonMode := CANNOT_BE_DIVERT;
							
						ELSIF Schematic.Segment[SubIndex].Type = mcACPTRAK_SEG_STR_660 THEN
							// The main segment is an AA, and the sub segment is an AA
							// Use the main segment as the reference
							ReferenceSeg := Schematic.Segment[MainIndex];
							OtherSeg := Schematic.Segment[SubIndex];
							ReferenceMode := MAIN_SEG_IS_REF;
							ComparisonMode := COMPARE_AA_AA;
							
						ELSIF Schematic.Segment[SubIndex].Type = mcACPTRAK_SEG_STR_105_TO_CIRC THEN
							// The main segment is an AA, and the sub segment is an AB
							// Use the main segment as the reference
							ReferenceSeg := Schematic.Segment[MainIndex];
							OtherSeg := Schematic.Segment[SubIndex];
							ReferenceMode := MAIN_SEG_IS_REF;
							ComparisonMode := COMPARE_AA_AB;
							
						ELSIF Schematic.Segment[SubIndex].Type = mcACPTRAK_SEG_CIRC_TO_STR_105 THEN
							// The main segment is an AA, and the sub segment is a BA
							// Use the main segment as the reference
							ReferenceSeg := Schematic.Segment[MainIndex];
							OtherSeg := Schematic.Segment[SubIndex];
							ReferenceMode := MAIN_SEG_IS_REF;
							ComparisonMode := COMPARE_AA_BA;
						END_IF
			
					mcACPTRAK_SEG_STR_105_TO_CIRC:
						// The main segment is an AB, check what the sub segment is
						IF Schematic.Segment[SubIndex].Type = mcACPTRAK_SEG_CIRC THEN
							// The sub segment is a BB, so this cannot be a divert
							ReferenceMode := REFERENCE_NOT_NEEDED;
							ComparisonMode := CANNOT_BE_DIVERT;
							
						ELSIF Schematic.Segment[SubIndex].Type = mcACPTRAK_SEG_STR_660 THEN
							// The main segment is an AB, and the sub segment is an AA
							// Use the sub segment as the reference
							ReferenceSeg := Schematic.Segment[SubIndex];
							OtherSeg := Schematic.Segment[MainIndex];
							ReferenceMode := SUB_SEG_IS_REF;
							ComparisonMode := COMPARE_AA_AB;
							
						ELSIF Schematic.Segment[SubIndex].Type = mcACPTRAK_SEG_STR_105_TO_CIRC THEN
							// The main segment is an AB, and the sub segment is an AB
							// Use the main segment as the reference
							ReferenceSeg := Schematic.Segment[MainIndex];
							OtherSeg := Schematic.Segment[SubIndex];
							ReferenceMode := MAIN_SEG_IS_REF;
							ComparisonMode := COMPARE_AB_AB;
							
						ELSIF Schematic.Segment[SubIndex].Type = mcACPTRAK_SEG_CIRC_TO_STR_105 THEN
							// The main segment is an AB, and the sub segment is a BA
							// Use the main segment as the reference
							ReferenceSeg := Schematic.Segment[MainIndex];
							OtherSeg := Schematic.Segment[SubIndex];
							ReferenceMode := MAIN_SEG_IS_REF;
							ComparisonMode := COMPARE_AB_BA;
						END_IF
			
					mcACPTRAK_SEG_CIRC_TO_STR_105:
						// The main segment is a BA, check what the sub segment is
						IF Schematic.Segment[SubIndex].Type = mcACPTRAK_SEG_CIRC THEN
							// The sub segment is a BB, so this cannot be a divert
							ReferenceMode := REFERENCE_NOT_NEEDED;
							ComparisonMode := CANNOT_BE_DIVERT;
							
						ELSIF Schematic.Segment[SubIndex].Type = mcACPTRAK_SEG_STR_660 THEN
							// The main segment is a BA, and the sub segment is an AA
							// Use the sub segment as the reference
							ReferenceSeg := Schematic.Segment[SubIndex];
							OtherSeg := Schematic.Segment[MainIndex];
							ReferenceMode := SUB_SEG_IS_REF;
							ComparisonMode := COMPARE_AA_BA;
							
						ELSIF Schematic.Segment[SubIndex].Type = mcACPTRAK_SEG_STR_105_TO_CIRC THEN
							// The main segment is a BA, and the sub segment is an AB
							// Use the sub segment as the reference
							ReferenceSeg := Schematic.Segment[SubIndex];
							OtherSeg := Schematic.Segment[MainIndex];
							ReferenceMode := SUB_SEG_IS_REF;
							ComparisonMode := COMPARE_AB_BA;
							
						ELSIF Schematic.Segment[SubIndex].Type = mcACPTRAK_SEG_CIRC_TO_STR_105 THEN
							// The main segment is a BA, and the sub segment is a BA
							// Use the main segment as the reference
							ReferenceSeg := Schematic.Segment[MainIndex];
							OtherSeg := Schematic.Segment[SubIndex];
							ReferenceMode := MAIN_SEG_IS_REF;
							ComparisonMode := COMPARE_BA_BA;
						END_IF
			
				END_CASE
				
				// ================================
				// =   DO THE CHOSEN COMPARISON   =
				// ================================
				CASE ComparisonMode OF
					
					COMPARE_AA_AA:
						IF PointToPointDist(OtherSeg.StartFrame,ReferenceSeg.StartFrame)                        >= (    94.631 - DIVERT_COMP_TOLERANCE) AND   // Other Start must be 94.631 - 1230.616 mm from Reference Start (+/- DIVERT_COMP_TOLERANCE)
							PointToPointDist(OtherSeg.StartFrame,ReferenceSeg.StartFrame)                        <= (  1230.616 + DIVERT_COMP_TOLERANCE) AND
							PointToPointDist(OtherSeg.StartFrame,ReferenceSeg.EndFrame  )                        >= (    30.000 - DIVERT_COMP_TOLERANCE) AND   // Other Start must be 30 - 571.039 mm from Reference End (+/- DIVERT_COMP_TOLERANCE)
							PointToPointDist(OtherSeg.StartFrame,ReferenceSeg.EndFrame  )                        <= (   571.039 + DIVERT_COMP_TOLERANCE) AND
							PointToPointDist(OtherSeg.EndFrame,  ReferenceSeg.StartFrame)                        >= (    30.000 - DIVERT_COMP_TOLERANCE) AND   // Other End must be 30 - 571.039 mm from Reference Start  (+/- DIVERT_COMP_TOLERANCE)
							PointToPointDist(OtherSeg.EndFrame,  ReferenceSeg.StartFrame)                        <= (   571.039 + DIVERT_COMP_TOLERANCE) AND
							PointToPointDist(OtherSeg.EndFrame,  ReferenceSeg.EndFrame  )                        >= (    94.631 - DIVERT_COMP_TOLERANCE) AND   // Other End 94.631 - 1230.616 mm from Reference End (+/- DIVERT_COMP_TOLERANCE)
							PointToPointDist(OtherSeg.EndFrame,  ReferenceSeg.EndFrame  )                        <= (  1230.616 + DIVERT_COMP_TOLERANCE) AND	
							PointToLineDist( OtherSeg.StartFrame,ReferenceSeg.StartFrame, ReferenceSeg.EndFrame) >= (DIVERT_GAP - DIVERT_GAP_TOLERANCE) AND   // Other Start must be DIVERT_GAP from the line formed by Reference Start and Reference End (+/- DIVERT_GAP_TOLERANCE)
							PointToLineDist( OtherSeg.StartFrame,ReferenceSeg.StartFrame, ReferenceSeg.EndFrame) <= (DIVERT_GAP + DIVERT_GAP_TOLERANCE) THEN
							// If all the criteria above are met, then this is a divert
							IsDivert := TRUE;
							// Calculate the overlap and midpoints
							Hypotenuse := PointToPointDist(ReferenceSeg.StartFrame,OtherSeg.StartFrame);
							Horizontal := SQRT(EXPT(Hypotenuse,2) - EXPT(DIVERT_GAP,2));
							IF Horizontal > 660 THEN
								Overlap := 1320 - Horizontal;
								ReferenceSegMidpoint := 660 - (Overlap / 2);
								OtherSegMidpoint := 660 - (Overlap / 2);
							ELSIF Horizontal <= 660 THEN
								Overlap := Horizontal;
								ReferenceSegMidpoint := (Overlap / 2);
								OtherSegMidpoint := (Overlap / 2);
							END_IF
						ELSE
							IsDivert := FALSE;
						END_IF
						
					COMPARE_AA_AB:
						IF PointToPointDist(OtherSeg.StartFrame,ReferenceSeg.StartFrame)                        >= (    94.631 - DIVERT_COMP_TOLERANCE) AND   // Other Start must be 94.631 - 675.916 mm from Reference Start  (+/- DIVERT_COMP_TOLERANCE)
							PointToPointDist(OtherSeg.StartFrame,ReferenceSeg.StartFrame)                        <= (   675.916 + DIVERT_COMP_TOLERANCE) AND
							PointToPointDist(OtherSeg.StartFrame,ReferenceSeg.EndFrame  )                        >= (    30.000 - DIVERT_COMP_TOLERANCE) AND   // Other Start must be 30 - 571.039 mm from Reference End (+/- DIVERT_COMP_TOLERANCE)
							PointToPointDist(OtherSeg.StartFrame,ReferenceSeg.EndFrame  )                        <= (   571.039 + DIVERT_COMP_TOLERANCE) AND
							PointToPointDist(OtherSeg.EndFrame,  ReferenceSeg.StartFrame)                        >= (    62.683 - DIVERT_COMP_TOLERANCE) AND   // Other End must be 62.683 - 362.647 mm from Reference Start  (+/- DIVERT_COMP_TOLERANCE)
							PointToPointDist(OtherSeg.EndFrame,  ReferenceSeg.StartFrame)                        <= (   362.647 + DIVERT_COMP_TOLERANCE) AND
							PointToPointDist(OtherSeg.EndFrame,  ReferenceSeg.EndFrame  )                        >= (   436.216 - DIVERT_COMP_TOLERANCE) AND   // Other End must be 436.216 - 1019.119 mm from Reference End (+/- DIVERT_COMP_TOLERANCE)
							PointToPointDist(OtherSeg.EndFrame,  ReferenceSeg.EndFrame  )                        <= (  1019.119 + DIVERT_COMP_TOLERANCE) AND	
							PointToLineDist( OtherSeg.StartFrame,ReferenceSeg.StartFrame, ReferenceSeg.EndFrame) >= (DIVERT_GAP - DIVERT_GAP_TOLERANCE) AND   // Other Start must be DIVERT_GAP from the line formed by Reference Start and Reference End (+/- DIVERT_GAP_TOLERANCE)
							PointToLineDist( OtherSeg.StartFrame,ReferenceSeg.StartFrame, ReferenceSeg.EndFrame) <= (DIVERT_GAP + DIVERT_GAP_TOLERANCE) THEN
							// If all the criteria above are met, then this is a divert
							IsDivert := TRUE;
							// Calculate the overlap and midpoints
							Hypotenuse := PointToPointDist(ReferenceSeg.StartFrame,OtherSeg.StartFrame);
							Horizontal := SQRT(EXPT(Hypotenuse,2) - EXPT(DIVERT_GAP,2));
							IF Horizontal >= 660 THEN
								Overlap := 105 - (Horizontal - 660);
								ReferenceSegMidpoint := 660 - (Overlap / 2);
								OtherSegMidpoint := (Horizontal - 660) + (Overlap / 2);
							ELSIF (Horizontal > 150) AND (Horizontal < 660) THEN
								Overlap := 105;
								ReferenceSegMidpoint := Horizontal - 52.5;
								OtherSegMidpoint := 52.5;
							ELSIF Horizontal <=105 THEN
								Overlap := Horizontal;
								ReferenceSegMidpoint := (Overlap / 2);
								OtherSegMidpoint := (Overlap / 2);
							END_IF
						ELSE
							IsDivert := FALSE;
						END_IF
					
					COMPARE_AA_BA:
						IF PointToPointDist(OtherSeg.StartFrame,ReferenceSeg.StartFrame)                        >= (   436.216 - DIVERT_COMP_TOLERANCE) AND   // Other Start must be 436.216 - 1019.119 mm from Reference Start (+/- DIVERT_COMP_TOLERANCE)
							PointToPointDist(OtherSeg.StartFrame,ReferenceSeg.StartFrame)                        <= (  1019.119 + DIVERT_COMP_TOLERANCE) AND
							PointToPointDist(OtherSeg.StartFrame,ReferenceSeg.EndFrame  )                        >= (    62.683 - DIVERT_COMP_TOLERANCE) AND   // Other Start must be 62.683 - 362.647 mm from Reference End (+/- DIVERT_COMP_TOLERANCE)
							PointToPointDist(OtherSeg.StartFrame,ReferenceSeg.EndFrame  )                        <= (   362.647 + DIVERT_COMP_TOLERANCE) AND
							PointToPointDist(OtherSeg.EndFrame,  ReferenceSeg.StartFrame)                        >= (    30.000 - DIVERT_COMP_TOLERANCE) AND   // Other End must be 30 - 571.039 mm from Reference Start (+/- DIVERT_COMP_TOLERANCE)
							PointToPointDist(OtherSeg.EndFrame,  ReferenceSeg.StartFrame)                        <= (   571.039 + DIVERT_COMP_TOLERANCE) AND
							PointToPointDist(OtherSeg.EndFrame,  ReferenceSeg.EndFrame  )                        >= (    94.631 - DIVERT_COMP_TOLERANCE) AND   // Other End must be 94.631 - 675.916 mm from Reference End (+/- DIVERT_COMP_TOLERANCE)
							PointToPointDist(OtherSeg.EndFrame,  ReferenceSeg.EndFrame  )                        <= (   675.916 + DIVERT_COMP_TOLERANCE) AND	
							PointToLineDist( OtherSeg.EndFrame,  ReferenceSeg.StartFrame, ReferenceSeg.EndFrame) >= (DIVERT_GAP - DIVERT_GAP_TOLERANCE) AND   // Other End must be DIVERT_GAP from the line formed by Reference Start and Reference End (+/- DIVERT_GAP_TOLERANCE)
							PointToLineDist( OtherSeg.EndFrame,  ReferenceSeg.StartFrame, ReferenceSeg.EndFrame) <= (DIVERT_GAP + DIVERT_GAP_TOLERANCE) THEN
							// If all the criteria above are met, then this is a divert
							IsDivert := TRUE;
							// Calculate the overlap and midpoints
							Hypotenuse := PointToPointDist(ReferenceSeg.EndFrame,OtherSeg.EndFrame);
							Horizontal := SQRT(EXPT(Hypotenuse,2) - EXPT(DIVERT_GAP,2));
							IF Horizontal >= 660 THEN
								Overlap := 105 - (Horizontal - 660);
								ReferenceSegMidpoint := (Overlap / 2);
								OtherSegMidpoint := 450 - ((Horizontal - 660) + (Overlap / 2));
							ELSIF (Horizontal > 150) AND (Horizontal < 660) THEN
								Overlap := 105;
								ReferenceSegMidpoint := 660 - (Horizontal - 52.5);
								OtherSegMidpoint := 397.5;
							ELSIF Horizontal <=105 THEN
								Overlap := Horizontal;
								ReferenceSegMidpoint := 660 - (Overlap / 2);
								OtherSegMidpoint := 450 - (Overlap / 2);
							END_IF
						ELSE
							IsDivert := FALSE;
						END_IF
					
					COMPARE_AB_AB:
						IF PointToPointDist(OtherSeg.StartFrame,ReferenceSeg.StartFrame) >= ( 94.631 - DIVERT_COMP_TOLERANCE) AND   // Other Start must be 94.631 - 109.442 mm from Reference Start (+/- DIVERT_COMP_TOLERANCE)
							PointToPointDist(OtherSeg.StartFrame,ReferenceSeg.StartFrame) <= (109.442 + DIVERT_COMP_TOLERANCE) AND
							PointToPointDist(OtherSeg.StartFrame,ReferenceSeg.EndFrame  ) >= (347.391 - DIVERT_COMP_TOLERANCE) AND   // Other Start must be 347.391 - 362.647 mm from Reference End (+/- DIVERT_COMP_TOLERANCE)
							PointToPointDist(OtherSeg.StartFrame,ReferenceSeg.EndFrame  ) <= (362.647 + DIVERT_COMP_TOLERANCE) AND
							PointToPointDist(OtherSeg.EndFrame,  ReferenceSeg.StartFrame) >= (347.391 - DIVERT_COMP_TOLERANCE) AND   // Other End must be 347.391 - 362.647 mm from Reference Start (+/- DIVERT_COMP_TOLERANCE)
							PointToPointDist(OtherSeg.EndFrame,  ReferenceSeg.StartFrame) <= (362.647 + DIVERT_COMP_TOLERANCE) AND
							PointToPointDist(OtherSeg.EndFrame,  ReferenceSeg.EndFrame  ) >= (794.373 - DIVERT_COMP_TOLERANCE) AND   // Other End must be 794.373 - 809.763 mm from Reference End (+/- DIVERT_COMP_TOLERANCE)
							PointToPointDist(OtherSeg.EndFrame,  ReferenceSeg.EndFrame  ) <= (809.763 + DIVERT_COMP_TOLERANCE) THEN
							// If all the criteria above are met, then this is a divert
							IsDivert := TRUE;
							// Calculate the overlap and midpoints
							Hypotenuse := PointToPointDist(ReferenceSeg.StartFrame,OtherSeg.StartFrame);
							Horizontal := SQRT(EXPT(Hypotenuse,2) - EXPT(DIVERT_GAP,2));
							Overlap := Horizontal;
							ReferenceSegMidpoint := (Overlap / 2);
							OtherSegMidpoint := (Overlap / 2);
						ELSE
							IsDivert := FALSE;
						END_IF
					
					COMPARE_AB_BA:
						IF PointToPointDist(OtherSeg.StartFrame,ReferenceSeg.StartFrame) >= (436.216 - DIVERT_COMP_TOLERANCE) AND   // Other Start must be 436.216 - 466.420 mm from Reference Start (+/- DIVERT_COMP_TOLERANCE)
							PointToPointDist(OtherSeg.StartFrame,ReferenceSeg.StartFrame) <= (466.420 + DIVERT_COMP_TOLERANCE) AND
							PointToPointDist(OtherSeg.StartFrame,ReferenceSeg.EndFrame  ) >= ( 95.366 - DIVERT_COMP_TOLERANCE) AND   // Other Start must be 95.366 - 96.578 mm from Reference End (+/- DIVERT_COMP_TOLERANCE)
							PointToPointDist(OtherSeg.StartFrame,ReferenceSeg.EndFrame  ) <= ( 96.578 + DIVERT_COMP_TOLERANCE) AND
							PointToPointDist(OtherSeg.EndFrame,  ReferenceSeg.StartFrame) >= ( 30.000 - DIVERT_COMP_TOLERANCE) AND   // Other End must be 30 - 33.654 mm from Reference Start (+/- DIVERT_COMP_TOLERANCE)
							PointToPointDist(OtherSeg.EndFrame,  ReferenceSeg.StartFrame) <= ( 33.654 + DIVERT_COMP_TOLERANCE) AND
							PointToPointDist(OtherSeg.EndFrame,  ReferenceSeg.EndFrame  ) >= (436.216 - DIVERT_COMP_TOLERANCE) AND   // Other End must be 436.216 - 466.420 mm from Reference End (+/- DIVERT_COMP_TOLERANCE)
							PointToPointDist(OtherSeg.EndFrame,  ReferenceSeg.EndFrame  ) <= (466.420 + DIVERT_COMP_TOLERANCE) THEN
							// If all the criteria above are met, then this is a divert
							IsDivert := TRUE;
							// Calculate the overlap and midpoints
							Hypotenuse := PointToPointDist(ReferenceSeg.StartFrame,OtherSeg.EndFrame);
							Horizontal := SQRT(EXPT(Hypotenuse,2) - EXPT(DIVERT_GAP,2));
							Overlap := 105 - Horizontal;
							ReferenceSegMidpoint := (Overlap / 2);
							OtherSegMidpoint := 450 - (Overlap / 2);
						ELSE
							IsDivert := FALSE;
						END_IF
					
					COMPARE_BA_BA:
						IF PointToPointDist(OtherSeg.StartFrame,ReferenceSeg.StartFrame) >= (794.373 - DIVERT_COMP_TOLERANCE) AND   // Other Start must be 794.373 - 809.763 mm from Reference Start (+/- DIVERT_COMP_TOLERANCE)
							PointToPointDist(OtherSeg.StartFrame,ReferenceSeg.StartFrame) <= (809.763 + DIVERT_COMP_TOLERANCE) AND
							PointToPointDist(OtherSeg.StartFrame,ReferenceSeg.EndFrame  ) >= (347.391 - DIVERT_COMP_TOLERANCE) AND   // Other Start must be 347.391 - 362.647 mm from Reference End (+/- DIVERT_COMP_TOLERANCE)
							PointToPointDist(OtherSeg.StartFrame,ReferenceSeg.EndFrame  ) <= (362.647 + DIVERT_COMP_TOLERANCE) AND
							PointToPointDist(OtherSeg.EndFrame,  ReferenceSeg.StartFrame) >= (347.391 - DIVERT_COMP_TOLERANCE) AND   // Other End must be 347.391 - 362.647 mm from Reference Start (+/- DIVERT_COMP_TOLERANCE)
							PointToPointDist(OtherSeg.EndFrame,  ReferenceSeg.StartFrame) <= (362.647 + DIVERT_COMP_TOLERANCE) AND
							PointToPointDist(OtherSeg.EndFrame,  ReferenceSeg.EndFrame  ) >= ( 94.631 - DIVERT_COMP_TOLERANCE) AND   // Other End must be 94.631 - 109.442 mm from Reference End (+/- DIVERT_COMP_TOLERANCE)
							PointToPointDist(OtherSeg.EndFrame,  ReferenceSeg.EndFrame  ) <= (109.442 + DIVERT_COMP_TOLERANCE) THEN
							// If all the criteria above are met, then this is a divert
							IsDivert := TRUE;
							// Calculate the overlap and midpoints
							Hypotenuse := PointToPointDist(ReferenceSeg.EndFrame,OtherSeg.EndFrame);
							Horizontal := SQRT(EXPT(Hypotenuse,2) - EXPT(DIVERT_GAP,2));
							Overlap := Horizontal;
							ReferenceSegMidpoint := 450 - (Overlap / 2);
							OtherSegMidpoint := 450 - (Overlap / 2);
						ELSE
							IsDivert := FALSE;
						END_IF
						
					COMPARE_NOT_SELECTED,CANNOT_BE_DIVERT:
						IsDivert:= FALSE;
					
				END_CASE
				
				// ==============================
				// =   RECORD THE INFORMATION   =
				// ==============================
				IF IsDivert THEN
					// Based on which segment is the reference, match the midpoints above to the respective outputs
					IF ReferenceMode = MAIN_SEG_IS_REF THEN
						MainSegDivMidpoint := ReferenceSegMidpoint;
						SubSegDivMidpoint := OtherSegMidpoint;
					ELSIF ReferenceMode = SUB_SEG_IS_REF THEN
						MainSegDivMidpoint := OtherSegMidpoint;
						SubSegDivMidpoint := ReferenceSegMidpoint;
					END_IF
					// Check if the divert is already known to the system
					FOR DivertIndex:=0 TO NUM_DIVERTS DO
						// If this entry is empty, then the list is empty or the non-empty entries have already been searched. Either way, store the divert here
						IF (Schematic.Diverts[DivertIndex].SegName[0] = '') THEN
							// Record the information for the divert at this index (and convert the meters to millimeters)
							Schematic.Diverts[DivertIndex].Overlap := Overlap / 1000;
							Schematic.Diverts[DivertIndex].SegName[0] := Schematic.Segment[MainIndex].Name;
							Schematic.Diverts[DivertIndex].SegID[0] := MainIndex;
							Schematic.Diverts[DivertIndex].DivertMid[0] := MainSegDivMidpoint / 1000;
							Schematic.Diverts[DivertIndex].SegName[1] := Schematic.Segment[SubIndex].Name;
							Schematic.Diverts[DivertIndex].SegID[1] := SubIndex;
							Schematic.Diverts[DivertIndex].DivertMid[1] := SubSegDivMidpoint / 1000;
							// Record the information for the main segment. If it is already a part of one divert, then use the second index
							IF NOT Schematic.Segment[MainIndex].Divert.Member[0] THEN
								Schematic.Segment[MainIndex].Divert.Member[0] := TRUE;
								Schematic.Segment[MainIndex].Divert.DivertID[0] := DivertIndex;
							ELSE
								Schematic.Segment[MainIndex].Divert.Member[1] := TRUE;
								Schematic.Segment[MainIndex].Divert.DivertID[1] := DivertIndex;
							END_IF
							// Break out of the for loop
							EXIT;
						// If the main and sub segments are already in an entry, then this divert is already known
						ELSIF (((Schematic.Diverts[DivertIndex].SegID[0] = MainIndex) OR (Schematic.Diverts[DivertIndex].SegID[0] = SubIndex)) AND
							((Schematic.Diverts[DivertIndex].SegID[1] = MainIndex) OR (Schematic.Diverts[DivertIndex].SegID[1] = SubIndex))) THEN
							// Record the information for the main segment. If it is already a part of one divert, then use the second index
							IF NOT Schematic.Segment[MainIndex].Divert.Member[0] THEN
								Schematic.Segment[MainIndex].Divert.Member[0] := TRUE;
								Schematic.Segment[MainIndex].Divert.DivertID[0] := DivertIndex;
							ELSE
								Schematic.Segment[MainIndex].Divert.Member[1] := TRUE;
								Schematic.Segment[MainIndex].Divert.DivertID[1] := DivertIndex;
							END_IF
							// Break out of the for loop
							EXIT;
						END_IF
					END_FOR
				END_IF
	
			END_IF
			
			// Reset everything
			IsDivert := FALSE;
			Overlap := 0;
			MainSegDivMidpoint := 0;
			SubSegDivMidpoint := 0;
			ReferenceSegMidpoint := 0;
			OtherSegMidpoint := 0;
			ReferenceMode := REFERENCE_NOT_SELECTED;
			ComparisonMode := COMPARE_NOT_SELECTED;
			Hypotenuse := 0;
			Horizontal := 0;
			
		END_FOR
		
	END_FOR
			
END_FUNCTION