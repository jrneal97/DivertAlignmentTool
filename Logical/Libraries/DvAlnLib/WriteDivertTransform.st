(*********************************************************************************
 * Copyright: B&R Industrial Automation GmbH 
 * Author:    nealj 
 * Created:   November 30, 2023/4:29 PM 
 * 
 *********************************************************************************)

FUNCTION WriteDivertTransform
	// Clear the transform
	brsmemset(ADR(Schematic.Svg.Transform),0,SIZEOF(Schematic.Svg.Transform));
	// Add the opening bracket
	Schematic.Svg.Transform := '[';
	// Find the first filled divert entry and set its color
	FOR i:=0 TO NUM_DIVERTS DO
		IF Schematic.Diverts[i].Overlap <> 0 THEN
			RectName.Value := i;
			RectName.String := INT_TO_STRING(RectName.Value);
			brsmemset(ADR(NewLine),0,SIZEOF(NewLine));
			NewLine := '{"select":"#Div_';
			NewLine := CONCAT(NewLine,RectName.String);
			// If not found yet, set grey (0)
			IF NOT Schematic.Diverts[i].Found THEN
				NewLine := CONCAT(NewLine,'","fill":0,"duration":0}');
			// If found, but not measured, set blue (1)
			ELSIF Schematic.Diverts[i].Found AND NOT Schematic.Diverts[i].Measurements.Measured THEN
				NewLine := CONCAT(NewLine,'","fill":1,"duration":0}');
			// If found and measured, set blue (1)
			ELSIF Schematic.Diverts[i].Found AND Schematic.Diverts[i].Measurements.Measured THEN
				NewLine := CONCAT(NewLine,'","fill":2,"duration":0}');
			END_IF
			brsstrcat(ADR(Schematic.Svg.Transform),ADR(NewLine));
			EXIT;
		END_IF
	END_FOR
	// For all subsequent diverts, set the color
	FOR i:=(i+1) TO NUM_DIVERTS DO
		IF Schematic.Diverts[i].Overlap <> 0 THEN
			RectName.Value := i;
			RectName.String := INT_TO_STRING(RectName.Value);
			brsmemset(ADR(NewLine),0,SIZEOF(NewLine));
			NewLine := ',{"select":"#Div_';					// <-- Note the comma at the front of the string to separate it from the previous transform
			NewLine := CONCAT(NewLine,RectName.String);
			// If not found yet, set grey (0)
			IF NOT Schematic.Diverts[i].Found THEN
				NewLine := CONCAT(NewLine,'","fill":0,"duration":0}');
				// If found, but not measured, set blue (1)
			ELSIF Schematic.Diverts[i].Found AND NOT Schematic.Diverts[i].Measurements.Measured THEN
				NewLine := CONCAT(NewLine,'","fill":1,"duration":0}');
				// If found and measured, set blue (1)
			ELSIF Schematic.Diverts[i].Found AND Schematic.Diverts[i].Measurements.Measured THEN
				NewLine := CONCAT(NewLine,'","fill":2,"duration":0}');
			END_IF
			brsstrcat(ADR(Schematic.Svg.Transform),ADR(NewLine));
		END_IF
	END_FOR
	// Add the closing bracket
	NewLine := ']';	
	brsstrcat(ADR(Schematic.Svg.Transform),ADR(NewLine));
	
END_FUNCTION