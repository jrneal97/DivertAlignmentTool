
PROGRAM _CYCLIC

	CASE AsmState OF
		
		// When the controller starts up, power on the trak
		ASM_IDLE:
			AsmReadInfo.Enable := TRUE;
			AsmReadStatus.Enable := TRUE;
			AsmState := ASM_POWER_ON;
			
		// If needed, power on the assembly and wait for it to power on
		ASM_POWER_ON:
			IF NOT AsmReadInfo.AssemblyInfo.PowerOn THEN
				AsmPowerOn.Execute := TRUE;
			ELSIF AsmReadInfo.AssemblyInfo.PowerOn AND AsmReadStatus.AssemblyReady THEN
				AsmPowerOn.Execute := FALSE;
				AsmState := ASM_FIND_ALL_SHUTTLES;
			END_IF
			
		// Wait for the start command, then get a list of all shuttles on the trak. Skip to ASM_RUNNING if there are no shuttles
		ASM_FIND_ALL_SHUTTLES:
			IF gStartTrak THEN
				AsmGetShuttle.Enable := TRUE;
				IF AsmGetShuttle.Valid THEN
					IF AsmGetShuttle.TotalCount > 0 THEN
						AsmState := ASM_READ_FROM_SHUTTLE;
					ELSE
						AsmGetShuttle.Enable := FALSE;
						AsmState := ASM_RUNNING;
					END_IF
				END_IF
			END_IF
		
		ASM_READ_FROM_SHUTTLE:
			AsmGetShuttle.Next := FALSE;
			// Read the userdata from the shuttle
			ShCopyUserData.Axis := ADR(AsmGetShuttle.Axis);
			ShCopyUserData.DataAddress := ADR(UserData);
			ShCopyUserData.DataSize := SIZEOF(UserData);
			ShCopyUserData.Mode := mcACPTRAK_USERDATA_GET;
			ShCopyUserData.Execute := TRUE;
			IF ShCopyUserData.Done THEN
				ShCopyUserData.Execute := FALSE;
				AsmState := ASM_WRITE_TO_SHUTTLE;
			END_IF
			
		// Make the shuttle grey, set its destination, and assign it a serial number
		ASM_WRITE_TO_SHUTTLE:
			// Set up intital userdata
			UserData.Red := 0.5;
			UserData.Green := 0.5;
			UserData.Blue := 0.5;
			IF UserData.ShuttleSerialNum = '' THEN
				SN_String := '';
				SN_Index := SN_Index + 1;
				SN_IndexStr := USINT_TO_STRING(SN_Index);
				SN_String := CONCAT(SN_String,SN_Prefix);
				SN_String := CONCAT(SN_String,SN_IndexStr);
				UserData.ShuttleSerialNum := SN_String;
			END_IF
			// Write the userdata to the shuttle
			ShCopyUserData.Axis := ADR(AsmGetShuttle.Axis);
			ShCopyUserData.DataAddress := ADR(UserData);
			ShCopyUserData.DataSize := SIZEOF(UserData);
			ShCopyUserData.Mode := mcACPTRAK_USERDATA_SET;
			ShCopyUserData.Execute := TRUE;
			IF ShCopyUserData.Done THEN
				ShCopyUserData.Execute := FALSE;
				AsmState := ASM_MOVE_SHUTTLE;
			END_IF
		
		// Send the shuttle to the destination defined above
		ASM_MOVE_SHUTTLE:
			RoutedMoveAbs.Axis := ADR(AsmGetShuttle.Axis);
			RoutedMoveAbs.Sector := ADR(SEC_MainLoop);
			RoutedMoveAbs.Position := 0.00;
			RoutedMoveAbs.Velocity := MotionParameters.Velocity;
			RoutedMoveAbs.Acceleration := MotionParameters.Acceleration;
			RoutedMoveAbs.Deceleration := MotionParameters.Deceleration;
			RoutedMoveAbs.AdvancedParameters.StartDirection := mcDIR_POSITIVE;
			RoutedMoveAbs.AdvancedParameters.EndDirection := mcDIR_POSITIVE;
			RoutedMoveAbs.AdvancedParameters.NumberOfTransitPoints := 0;
			RoutedMoveAbs.Execute := TRUE;
			AsmState := ASM_CHECK_FOR_MORE;
		
		// Once the move is active, check for remaining shuttles
		ASM_CHECK_FOR_MORE:
			IF RoutedMoveAbs.Active THEN
				RoutedMoveAbs.Execute := FALSE;
				IF AsmGetShuttle.RemainingCount > 0 THEN
					AsmGetShuttle.Next := TRUE;
					AsmState := ASM_READ_FROM_SHUTTLE;
				ELSE
					AsmGetShuttle.Enable := FALSE;
					AsmState := ASM_RUNNING;
				END_IF
			END_IF
		
		// All shuttles have been put in motion
		ASM_RUNNING:
			// Reset the start command
			gStartTrak := FALSE;
			// If the stop command is issued, stop all shuttles
			IF gStopTrak THEN
				AsmStop.Execute := TRUE;
				IF AsmStop.Done THEN
					AsmStop.Execute := FALSE;
					AsmState := ASMSTOP_FIND_ALL_SHUTTLES;
				END_IF
			END_IF
				
		// ===========================================================
		// GET ALL SHUTTLES TO BE STOPPED AT THE START OF THE TOP LOOP
		// ===========================================================
		// Get a list of all shuttles on the trak. Skip to ASM_RUNNING if there are no shuttles
		ASMSTOP_FIND_ALL_SHUTTLES:
			AsmGetShuttle.Enable := TRUE;
			IF AsmGetShuttle.Valid THEN
				IF AsmGetShuttle.TotalCount > 0 THEN
					AsmState := ASMSTOP_READ_FROM_SHUTTLE;
				ELSE
					AsmGetShuttle.Enable := FALSE;
					gStopTrak := FALSE;
					AsmState := ASM_IDLE;
				END_IF
			END_IF
			
		ASMSTOP_READ_FROM_SHUTTLE:
			AsmGetShuttle.Next := FALSE;
			// Read the userdata from the shuttle
			ShCopyUserData.Axis := ADR(AsmGetShuttle.Axis);
			ShCopyUserData.DataAddress := ADR(UserData);
			ShCopyUserData.DataSize := SIZEOF(UserData);
			ShCopyUserData.Mode := mcACPTRAK_USERDATA_GET;
			ShCopyUserData.Execute := TRUE;
			IF ShCopyUserData.Done THEN
				ShCopyUserData.Execute := FALSE;
				AsmState := ASMSTOP_WRITE_TO_SHUTTLE;
			END_IF
			
		// Make the shuttle black, and set its destination
		ASMSTOP_WRITE_TO_SHUTTLE:
			// Set userdata to reflect the stop
			UserData.Red := 0.0;
			UserData.Green := 0.0;
			UserData.Blue := 0.0;
			// Write the userdata to the shuttle
			ShCopyUserData.Axis := ADR(AsmGetShuttle.Axis);
			ShCopyUserData.DataAddress := ADR(UserData);
			ShCopyUserData.DataSize := SIZEOF(UserData);
			ShCopyUserData.Mode := mcACPTRAK_USERDATA_SET;
			ShCopyUserData.Execute := TRUE;
			IF ShCopyUserData.Done THEN
				ShCopyUserData.Execute := FALSE;
				AsmState := ASMSTOP_MOVE_SHUTTLE;
			END_IF
		
		// Send the shuttle to the destination defined above
		ASMSTOP_MOVE_SHUTTLE:
			RoutedMoveAbs.Axis := ADR(AsmGetShuttle.Axis);
			RoutedMoveAbs.Sector := ADR(SEC_MainLoop);
			RoutedMoveAbs.Position := 0.00;
			RoutedMoveAbs.Velocity := MotionParameters.Velocity;
			RoutedMoveAbs.Acceleration := MotionParameters.Acceleration;
			RoutedMoveAbs.Deceleration := MotionParameters.Deceleration;
			RoutedMoveAbs.AdvancedParameters.StartDirection := mcDIR_UNDEFINED;
			RoutedMoveAbs.AdvancedParameters.EndDirection := mcDIR_POSITIVE;
			RoutedMoveAbs.Execute := TRUE;
			AsmState := ASMSTOP_CHECK_FOR_MORE;
		
		// Once the move is active, check for remaining shuttles
		ASMSTOP_CHECK_FOR_MORE:
			IF RoutedMoveAbs.Active THEN
				RoutedMoveAbs.Execute := FALSE;
				IF AsmGetShuttle.RemainingCount > 0 THEN
					AsmGetShuttle.Next := TRUE;
					AsmState := ASMSTOP_READ_FROM_SHUTTLE;
				ELSE
					AsmGetShuttle.Enable := FALSE;
					gStopTrak := FALSE;
					AsmState := ASM_IDLE;
				END_IF
			END_IF
			
		// Example error state
		ASM_ERROR:
			
		
	END_CASE

	// Call FUBs
	AsmPowerOn();
	AsmPowerOff();
	AsmReadInfo();
	AsmReadStatus();
	AsmGetShuttle();
	AsmStop();
	ShCopyUserData();
	RoutedMoveAbs();
	SecAddShuttle();
	
END_PROGRAM
