(*********************************************************************************
 * Copyright: B&R Industrial Automation GmbH
 * Author:    nealj
 * Created:   November 9, 2022/2:23 PM
 * There are three state machines running in this function block.
 *
 * The first is for the buffer. When enabled and not recovering, the buffer
 * catches shuttles and adds them to a queue. Upon disabling the FUB or starting
 * recovery the buffer erases all shuttles from the queue.If recovery was started,
 * the buffer waits for the recovery done signal. After recovery, the buffer waits
 * for the next shuttle
 *
 * The second for is the slots. When enabled and the tooling is clear and not
 * recovering, the slots look to the queue and pull shuttles from it to fill slots.
 * When the slots are filled, the SlotsFilled output is set and they wait for the
 * release command. When the release command is set, the shuttles are written to
 * and sent to the target. Before pulling the first shuttle each time, it checks if
 * that shuttle is meant for another station. If so, it allows the shuttle to
 * bypass the station (technically it does a routed move to that shuttles
 * destination).Upon disabling the FUB or starting recovery the slots stop what
 * they are doing.If recovery was started, the slots wait for the recovery done
 * signal. After recovery, the slots either finish filling or wait for the release
 * signal depending on the number of slots already filled
 *
 * The third is for recovery. Once the slots and buffer are waiting for recovery,
 * the recovery sequence can begin. First, all shuttles on the sector are
 * discovered. Then all are sent to the start of the sector one at a time. From
 * here, it is calculated how many shuttles can fit behind the buffer. Starting
 * at the front, any shuttles that won't fit behind the buffer or go to slots is
 * sent away to the target one at a time. Then the slots are filled one at a time.
 * Last, the remaining shuttles are sent to the buffer point and added to the
 * queue. If the recover command is dropped during recovery, recovery still
 * finishes.
 *********************************************************************************)

FUNCTION_BLOCK MultiUpStn
	Internal.ActiveSlots := 0;
	FOR Internal.ActiveIndex:=1 TO MAX_NUM_SLOTS DO
		// For all slots, if the sector isn't null, the slot is enabled
		Internal.SlotEnabled[Internal.ActiveIndex] := (SelfDetails[Internal.ActiveIndex].SectorReference <> 0);
		IF (SelfDetails[Internal.ActiveIndex].SectorReference <> 0) THEN
			// If the sector isn't null, increment the total active slots
			Internal.ActiveSlots := Internal.ActiveSlots + 1;
			// The last active slot in the for loop is the farthest slot from the buffer (and should be the first one to pull from the queue)
			Internal.FarthestSlot := Internal.ActiveIndex;
		END_IF

	END_FOR

	IF Error THEN
		Internal.BufferState := BUF_ERROR;
		Internal.SlotsState := SLOTS_ERROR;
		Internal.RecoveryState := RECOV_ERROR;
	END_IF

	// If disabled, reset everything
	IF NOT Enable THEN
		// Reset internal vars
		Internal.BehindBuffer := 0;
		Internal.BufferIndex := 0;
		Internal.FubIndex := 0;
		Internal.RecovBufferIndex := 0;
		Internal.RecoveryFilledSlots := 0;
		Internal.RecoveryIndex := 0;
		Internal.SendAway := 0;
		Internal.SlotIndex := 0;
		brsmemset(ADR(Internal.SlotShuttleRefs),0,SIZEOF(Internal.SlotShuttleRefs));
		brsmemset(ADR(Internal.StationBuffer),0,SIZEOF(Internal.StationBuffer));
		Internal.TempShuttleReleased := 0;
		Internal.TempSlotsFilled := 0;
		Internal.TempUserdataWritten := 0;
		// Reset all FUBs
		Internal.Fubs.BarrierCommand.Execute := FALSE;
		Internal.Fubs.BarrierReadInfo.Enable := FALSE;
		Internal.Fubs.ElasticMoveAbs[0].Execute := FALSE;
		Internal.Fubs.ElasticMoveAbs[1].Execute := FALSE;
		Internal.Fubs.ElasticMoveAbs[2].Execute := FALSE;
		Internal.Fubs.ElasticMoveAbs[3].Execute := FALSE;
		Internal.Fubs.ElasticMoveAbs[4].Execute := FALSE;
		Internal.Fubs.ElasticMoveAbs[5].Execute := FALSE;
		Internal.Fubs.ElasticMoveAbs[6].Execute := FALSE;
		Internal.Fubs.RecoveryTimer.IN := FALSE;
		Internal.Fubs.RoutedMoveAbs[0].Execute := FALSE;
		Internal.Fubs.RoutedMoveAbs[1].Execute := FALSE;
		Internal.Fubs.RoutedMoveAbs[2].Execute := FALSE;
		Internal.Fubs.RoutedMoveAbs[3].Execute := FALSE;
		Internal.Fubs.RoutedMoveAbs[4].Execute := FALSE;
		Internal.Fubs.RoutedMoveAbs[5].Execute := FALSE;
		Internal.Fubs.RoutedMoveAbs[6].Execute := FALSE;
		Internal.Fubs.SecGetShuttleSel.Enable := FALSE;
		Internal.Fubs.SecStop.Execute := FALSE;
		Internal.Fubs.ShCopyUserData[0].Execute := FALSE;
		Internal.Fubs.ShCopyUserData[1].Execute := FALSE;
		Internal.Fubs.ShCopyUserData[2].Execute := FALSE;
		Internal.Fubs.ShCopyUserData[3].Execute := FALSE;
		Internal.Fubs.ShCopyUserData[4].Execute := FALSE;
		Internal.Fubs.ShCopyUserData[5].Execute := FALSE;
		Internal.Fubs.ShCopyUserData[6].Execute := FALSE;
		Internal.Fubs.ShReadInfo[0].Enable := FALSE;
		Internal.Fubs.ShReadInfo[1].Enable := FALSE;
		Internal.Fubs.ShReadInfo[2].Enable := FALSE;
		Internal.Fubs.ShReadInfo[3].Enable := FALSE;
		Internal.Fubs.ShReadInfo[4].Enable := FALSE;
		Internal.Fubs.ShReadInfo[5].Enable := FALSE;
		Internal.Fubs.ShReadInfo[6].Enable := FALSE;
		Internal.Fubs.ShSwitchSector.Execute := FALSE;
		Internal.Fubs.TrgPointEnable.Enable := FALSE;
		Internal.Fubs.TrgPointGetInfo.Execute := FALSE;
	END_IF
	
	// ===================================================================================================================================================================
	// || STATE MACHINES ||***********************************************************************************************************************************************
	// ===================================================================================================================================================================

	// BUFFER ------------------------------------------------------------------------------------------------------------------------------------------------------------
	// Initialize the process point FUBs
	Internal.Fubs.TrgPointEnable.ProcessPoint := SelfDetails[0].ProcessPointReference;
	Internal.Fubs.TrgPointGetInfo.ProcessPoint := SelfDetails[0].ProcessPointReference;

	// Directly link the TrgPointEnable enable to the enable and recover status of the station
	Internal.Fubs.TrgPointEnable.Enable := Enable;

	CASE Internal.BufferState OF
		BUF_DISABLED:
			// If recovery requested, go to recovering state
			IF (Enable AND Recover AND NOT Error) THEN
				Internal.BufferState := BUF_RECOVERING;
			// If enabled and not recovering, begin buffer operations
			ELSIF (Enable AND NOT Recover AND NOT Error) THEN
				Internal.BufferState := BUF_WAIT_FOR_SH;
			END_IF

		BUF_WAIT_FOR_SH:
			IF (NOT Enable) OR Recover THEN
				Internal.BufferState := BUF_CLEAR_QUEUE;
			// If a shuttle was detected, get its info
			ELSIF Internal.Fubs.TrgPointEnable.EventCount > 0 THEN
				Internal.Fubs.TrgPointGetInfo.Execute := TRUE;
				Internal.BufferState := BUF_READ_SH;
			END_IF

		BUF_READ_SH:
			IF (NOT Enable) OR Recover THEN
				Internal.Fubs.TrgPointGetInfo.Execute := FALSE;
				Internal.BufferState := BUF_CLEAR_QUEUE;
			// Once the shuttles info is read, send it to the self[0] position (this is the buffer)
			ELSIF Internal.Fubs.TrgPointGetInfo.Done THEN
				tbBufferAddSh(ADR(Internal.StationBuffer),ADR(Internal.Fubs.TrgPointGetInfo.TrgPointInfo.Axis));
				Internal.BufferState := BUF_STAGE_SH;
			END_IF

		BUF_STAGE_SH:
			IF (NOT Enable) OR Recover THEN
				Internal.Fubs.TrgPointGetInfo.Execute := FALSE;
				Internal.Fubs.RoutedMoveAbs[0].Execute := FALSE;
				Internal.BufferState := BUF_CLEAR_QUEUE;
			END_IF
			// Once the move is active, wait for the next shuttle
			Internal.Fubs.TrgPointGetInfo.Execute := FALSE;
			Internal.BufferState := BUF_WAIT_FOR_SH;

		BUF_CLEAR_QUEUE:
			// Remove all shuttles from the queue before going into the disabled state
			IF tbBufferShAvailable(ADR(Internal.StationBuffer)) THEN
				tbBufferRemoveFirst(ADR(Internal.StationBuffer));
			ELSE
				Internal.BufferState := BUF_DISABLED;
			END_IF

		BUF_RECOVERING:
			// If enable drops, recovery will be aborted
			IF NOT Enable THEN
				Internal.BufferState := BUF_DISABLED;
			// If recovery is finished, return to the disabled state.
			ELSIF RecoveryDone  AND NOT Recover THEN
				// The recovery will have put shuttles in the queue if there were any shuttles, so the buffer should wait for the next shuttle
				Internal.BufferState := BUF_DISABLED;
			END_IF

		BUF_ERROR:
			// Wait for the reset signal. Then clear everything and go to the disabled state
			IF ErrorReset THEN
				Internal.BufferState := BUF_DISABLED;
			END_IF

	END_CASE

	// SLOTS -------------------------------------------------------------------------------------------------------------------------------------------------------------
	// Initialize the sector stop FUB
	Internal.Fubs.SecStop.Sector := SelfDetails[0].SectorReference;
	Internal.Fubs.SecStop.AdvancedParameters.StopMode := mcSTOPMODE_JERK_LIMIT;
	Internal.Fubs.SecStop.AdvancedParameters.Deceleration := MotionParameters.Deceleration;

	CASE Internal.SlotsState OF
		SLOTS_DISABLED:
			// If recovery requested, go to recovering state
			IF (Enable AND Recover AND NOT Error) THEN
				Internal.SlotsState := SLOTS_RECOVERING;
			// If enabled and not recovering and the tooling is clear, begin slot operations
			ELSIF (Enable AND NOT Recover AND ToolingClear AND NOT Error) THEN
				// If the slot index is zero, then the Fub is just starting. Set the index to the farthest active slot
				IF Internal.SlotIndex = 0 AND NOT Internal.RecoveryFilledSlots THEN
					Internal.SlotIndex := Internal.FarthestSlot;
				END_IF
				// If recovery sent shuttles to all slots, confirm their arrival
				IF Internal.RecoveryFilledSlots THEN
					Internal.RecoveryFilledSlots := FALSE;
					Internal.SlotsState := SLOTS_CONFIRM_SLOTS_FULL;
				// Otherwise send shuttle(s) to slot(s)
				ELSE
					Internal.SlotsState := SLOTS_WAIT_FOR_QUEUE;
				END_IF
			END_IF

		SLOTS_WAIT_FOR_QUEUE:
			// If the tooling is no longer clear and filling has begun, raise an error and stop all shuttles
			IF NOT ToolingClear AND FillingSlots THEN
				Internal.Fubs.SecStop.Execute := TRUE;
				Error := TRUE;
				ErrorText := 'Tooling no longer clear during slot filling';
				Internal.SlotsState := SLOTS_ERROR;
			// If the FUB was disabled or recovery was requested or tooling isn't clear (while not filling slots) go to the disabled state
			ELSIF NOT(Enable AND NOT Recover AND ToolingClear) THEN
				FillingSlots := FALSE;
				Internal.SlotIndex := 0;
				Internal.SlotsState := SLOTS_DISABLED;
			// Once there is a shuttle in the queue, get its reference and read its userdata
			ELSIF tbBufferShAvailable(ADR(Internal.StationBuffer)) THEN
				FillingSlots := TRUE;
				tbBufferGetFirst(ADR(Internal.StationBuffer),ADR(Internal.SlotShuttleRefs[Internal.SlotIndex]));
				tbBufferRemoveFirst(ADR(Internal.StationBuffer));
				Internal.Fubs.ShCopyUserData[Internal.SlotIndex].Axis := ADR(Internal.SlotShuttleRefs[Internal.SlotIndex]);
				Internal.Fubs.ShCopyUserData[Internal.SlotIndex].DataAddress := ADR(UserData[Internal.SlotIndex]);
				Internal.Fubs.ShCopyUserData[Internal.SlotIndex].DataSize := SIZEOF(UserData[Internal.SlotIndex]);
				Internal.Fubs.ShCopyUserData[Internal.SlotIndex].Mode := mcACPTRAK_USERDATA_GET;
				Internal.Fubs.ShCopyUserData[Internal.SlotIndex].Execute := TRUE;
				Internal.SlotsState := SLOTS_READ_USERDATA;
			END_IF

		SLOTS_READ_USERDATA:
			// If the tooling is no longer clear at this point, raise an error and stop all shuttles
			IF NOT ToolingClear THEN
				Internal.Fubs.ShCopyUserData[Internal.SlotIndex].Execute := FALSE;
				Internal.Fubs.SecStop.Execute := TRUE;
				Error := TRUE;
				ErrorText := 'Tooling is not clear during slot filling';
				Internal.SlotsState := SLOTS_ERROR;
			// If the FUB was disabled or recovery was requested go to the disabled state
			ELSIF NOT(Enable AND NOT Recover) THEN
				FillingSlots := FALSE;
				Internal.SlotIndex := 0;
				Internal.Fubs.ShCopyUserData[Internal.SlotIndex].Execute := FALSE;
				Internal.SlotsState := SLOTS_DISABLED;
			// Once the userdata is read, check the shuttles destination
			ELSIF Internal.Fubs.ShCopyUserData[Internal.SlotIndex].Done THEN
				Internal.Fubs.ShCopyUserData[Internal.SlotIndex].Execute := FALSE;
				// If shuttle is going to go to the farthest slot, therefor first in the group, and it not meant for this station...allow the shuttle to bypass
				IF Internal.SlotIndex = Internal.FarthestSlot AND NOT(UserData[Internal.SlotIndex].Destination.SubstationID = SelfDetails[0].SubstationID) THEN
					// Based on the movement type of the destination, do a vel or abs move to that destination
                    Internal.Fubs.RoutedMoveAbs[Internal.SlotIndex].Axis := ADR(Internal.SlotShuttleRefs[Internal.SlotIndex]);
                    Internal.Fubs.RoutedMoveAbs[Internal.SlotIndex].Sector := UserData[Internal.SlotIndex].Destination.SectorReference;
                    Internal.Fubs.RoutedMoveAbs[Internal.SlotIndex].Position := UserData[Internal.SlotIndex].Destination.Position;
                    Internal.Fubs.RoutedMoveAbs[Internal.SlotIndex].Velocity := MotionParameters.Velocity;
                    Internal.Fubs.RoutedMoveAbs[Internal.SlotIndex].Acceleration := MotionParameters.Acceleration;
                    Internal.Fubs.RoutedMoveAbs[Internal.SlotIndex].Deceleration := MotionParameters.Deceleration;
                    Internal.Fubs.RoutedMoveAbs[Internal.SlotIndex].AdvancedParameters.StartDirection := mcDIR_UNDEFINED;
                    Internal.Fubs.RoutedMoveAbs[Internal.SlotIndex].AdvancedParameters.EndDirection := mcDIR_POSITIVE;
                    Internal.Fubs.RoutedMoveAbs[Internal.SlotIndex].AdvancedParameters.ShuttleOrientation := mcDIR_UNDEFINED;
                    Internal.Fubs.RoutedMoveAbs[Internal.SlotIndex].Execute := TRUE;
					Internal.SlotsState := SLOTS_SEND_ON;
				// For any other shuttle, change the destination to the current slot (SlotIndex) and send to the current slot (SlotIndex)
				ELSE
					UserData[Internal.SlotIndex].Destination := SelfDetails[Internal.SlotIndex];
					Internal.Fubs.RoutedMoveAbs[Internal.SlotIndex].Axis := ADR(Internal.SlotShuttleRefs[Internal.SlotIndex]);
					Internal.Fubs.RoutedMoveAbs[Internal.SlotIndex].Sector := SelfDetails[Internal.SlotIndex].SectorReference;
					Internal.Fubs.RoutedMoveAbs[Internal.SlotIndex].Position := SelfDetails[Internal.SlotIndex].Position;
					Internal.Fubs.RoutedMoveAbs[Internal.SlotIndex].Velocity := MotionParameters.Velocity;
					Internal.Fubs.RoutedMoveAbs[Internal.SlotIndex].Acceleration := MotionParameters.Acceleration;
					Internal.Fubs.RoutedMoveAbs[Internal.SlotIndex].Deceleration := MotionParameters.Deceleration;
					Internal.Fubs.RoutedMoveAbs[Internal.SlotIndex].AdvancedParameters.StartDirection := mcDIR_UNDEFINED;
					Internal.Fubs.RoutedMoveAbs[Internal.SlotIndex].AdvancedParameters.EndDirection := mcDIR_POSITIVE;
					Internal.Fubs.RoutedMoveAbs[Internal.SlotIndex].AdvancedParameters.ShuttleOrientation := mcDIR_UNDEFINED;
					Internal.Fubs.RoutedMoveAbs[Internal.SlotIndex].Execute := TRUE;
					Internal.Fubs.ShReadInfo[Internal.SlotIndex].Axis := ADR(Internal.SlotShuttleRefs[Internal.SlotIndex]);
					Internal.Fubs.ShReadInfo[Internal.SlotIndex].Enable := TRUE;
					Internal.SlotsState := SLOTS_MOVE_TO_SLOT;
				END_IF
			END_IF

		SLOTS_MOVE_TO_SLOT:
			// If the tooling is no longer clear at this point, raise an error and stop all shuttles
			IF NOT ToolingClear THEN
				Internal.Fubs.RoutedMoveAbs[Internal.SlotIndex].Execute := FALSE;
				Internal.Fubs.SecStop.Execute := TRUE;
				Error := TRUE;
				ErrorText := 'Tooling is not clear during slot filling';
				Internal.SlotsState := SLOTS_ERROR;
			// If the FUB was disabled or recovery was requested go to the disabled state
			ELSIF NOT(Enable AND NOT Recover) THEN
				FillingSlots := FALSE;
				Internal.SlotIndex := 0;
				Internal.Fubs.RoutedMoveAbs[Internal.SlotIndex].Execute := FALSE;
				Internal.SlotsState := SLOTS_DISABLED;
			// If the absolute move is active, then decide what to do based on the slot index
			ELSIF Internal.Fubs.RoutedMoveAbs[Internal.SlotIndex].Active THEN
				Internal.SlotIndex := Internal.SlotIndex - 1;
				IF Internal.SlotIndex <> 0 THEN
					// If the related slot is disabled, decrement again. If the slot index becomes zero, break out
					WHILE SelfDetails[Internal.SlotIndex].SectorReference = 0 DO
						Internal.SlotIndex := Internal.SlotIndex - 1;
						IF Internal.SlotIndex = 0 THEN
							EXIT;
						END_IF
					END_WHILE
				END_IF
				// If this index is zero confirm slots full
				IF Internal.SlotIndex = 0 THEN
					Internal.SlotsState := SLOTS_CONFIRM_SLOTS_FULL;
				// If the index isn't zero and the reference isn't null, then the slot needs a shuttle
				ELSIF SelfDetails[Internal.SlotIndex].SectorReference <> 0 THEN
					Internal.SlotsState := SLOTS_WAIT_FOR_QUEUE;
				END_IF
			END_IF

		SLOTS_CONFIRM_SLOTS_FULL:
			// Every cycle, count the number of slots that have finished the move or arent enabled. If the count = MAX_NUM_SLOTS, then all slots are done
			Internal.TempSlotsFilled := 0;
			FOR Internal.SlotIndex:=1 TO MAX_NUM_SLOTS DO
				IF ((Internal.Fubs.ElasticMoveAbs[Internal.SlotIndex].Done OR Internal.Fubs.RoutedMoveAbs[Internal.SlotIndex].Done) OR NOT Internal.SlotEnabled[Internal.SlotIndex]) THEN
					Internal.TempSlotsFilled := Internal.TempSlotsFilled + 1;
				END_IF
			END_FOR
			// If the tooling is no longer clear at this point, raise an error and stop all shuttles
			IF NOT ToolingClear THEN
				FOR Internal.SlotIndex:=1 TO MAX_NUM_SLOTS DO
                    Internal.Fubs.RoutedMoveAbs[Internal.SlotIndex].Execute := FALSE;
					Internal.Fubs.ElasticMoveAbs[Internal.SlotIndex].Execute := FALSE;
				END_FOR
				Internal.Fubs.SecStop.Execute := TRUE;
				Error := TRUE;
				ErrorText := 'Tooling is not clear during slot filling';
				Internal.SlotsState := SLOTS_ERROR;
			// If the FUB was disabled or recovery was requested go to the disabled state
			ELSIF NOT(Enable AND NOT Recover) THEN
				FillingSlots := FALSE;
				Internal.SlotIndex := 0;
				FOR Internal.SlotIndex:=1 TO MAX_NUM_SLOTS DO
                    Internal.Fubs.RoutedMoveAbs[Internal.SlotIndex].Execute := FALSE;
					Internal.Fubs.ElasticMoveAbs[Internal.SlotIndex].Execute := FALSE;
				END_FOR
				Internal.SlotsState := SLOTS_DISABLED;
			// If the count = MAX_NUM_SLOTS, then all slots are done. Lower the filling output, set the filled ouput, and reset the move commands
			ELSIF Internal.TempSlotsFilled = MAX_NUM_SLOTS THEN
				FillingSlots := FALSE;
				SlotsFilled := TRUE;
				FOR Internal.SlotIndex:=1 TO MAX_NUM_SLOTS DO
                    Internal.Fubs.RoutedMoveAbs[Internal.SlotIndex].Execute := FALSE;
					Internal.Fubs.ElasticMoveAbs[Internal.SlotIndex].Execute := FALSE;
					Internal.Fubs.ShReadInfo[Internal.SlotIndex].Enable := FALSE;
				END_FOR
				Internal.SlotsState := SLOTS_WAIT_FOR_RELEASE;
			END_IF

		SLOTS_WAIT_FOR_RELEASE:
			// If the tooling is no longer clear at this point, that is normal
			// If the FUB was disabled or recovery was requested go to the disabled state
			IF NOT(Enable AND NOT Recover) THEN
				SlotsFilled := FALSE;
				Internal.SlotIndex := 0;
				Internal.SlotsState := SLOTS_DISABLED;
			// Wait for the release command
			ELSIF ReleaseShuttles THEN
				SlotsFilled := FALSE;
				// Check every slot
				FOR Internal.SlotIndex:=1 TO MAX_NUM_SLOTS DO
					// If the slot is enabled, write the target destination to the shuttle
					IF Internal.SlotEnabled[Internal.SlotIndex] THEN
						UserData[Internal.SlotIndex].Destination := TargetDetails;
						// If the shuttle came in with the recovered flag true, that means it came in mid recovery so the recover flag would have been
						// reset by the reset sequence, but the userdata was already read by this FUB. Reset it again
						UserData[Internal.SlotIndex].Recovered := FALSE;
						Internal.Fubs.ShCopyUserData[Internal.SlotIndex].Axis := ADR(Internal.SlotShuttleRefs[Internal.SlotIndex]);
						Internal.Fubs.ShCopyUserData[Internal.SlotIndex].DataAddress := ADR(UserData[Internal.SlotIndex]);
						Internal.Fubs.ShCopyUserData[Internal.SlotIndex].DataSize := SIZEOF(UserData[Internal.SlotIndex]);
						Internal.Fubs.ShCopyUserData[Internal.SlotIndex].Mode := mcACPTRAK_USERDATA_SET;
                        Internal.Fubs.ShCopyUserData[Internal.SlotIndex].Execute := TRUE;
					END_IF
				END_FOR
				Internal.SlotsState := SLOTS_RELEASE_SHUTTLES;
			END_IF

		SLOTS_RELEASE_SHUTTLES:
			// Every cycle, count the number of slots that have finished writing userdata or are disabled. If the count = MAX_NUM_SLOTS, then all slots are done
            // TempUserDataWritten is reset in the SLOTS_ERROR state in case of an error during this process
			Internal.TempUserdataWritten := 0;
			FOR Internal.SlotIndex:=1 TO MAX_NUM_SLOTS DO
				IF (Internal.Fubs.ShCopyUserData[Internal.SlotIndex].Done OR NOT Internal.SlotEnabled[Internal.SlotIndex]) THEN
					Internal.TempUserdataWritten := Internal.TempUserdataWritten + 1;
				END_IF
			END_FOR
			// If the tooling is not clear at this point, raise an error and stop all shuttles
			IF NOT ToolingClear THEN
				FOR Internal.SlotIndex:=1 TO MAX_NUM_SLOTS DO
					Internal.Fubs.ShCopyUserData[Internal.SlotIndex].Execute := FALSE;
				END_FOR
				Internal.Fubs.SecStop.Execute := TRUE;
				Error := TRUE;
				ErrorText := 'Tooling is not clear during release';
				Internal.SlotsState := SLOTS_ERROR;
			// If the FUB was disabled or recovery was requested go to the disabled state
			ELSIF NOT(Enable AND NOT Recover) THEN
				FOR Internal.SlotIndex:=1 TO MAX_NUM_SLOTS DO
					Internal.Fubs.ShCopyUserData[Internal.SlotIndex].Execute := FALSE;
				END_FOR
				Internal.SlotsState := SLOTS_DISABLED;
			// If the count = MAX_NUM_SLOTS, then all slots are done. Send the shuttles away
			ELSIF Internal.TempUserdataWritten = MAX_NUM_SLOTS THEN
				// Check every slot
				FOR Internal.SlotIndex:=1 TO MAX_NUM_SLOTS DO
					// If the slot is enabled, reset the userdata writing and send the shuttle to the target
					IF Internal.SlotEnabled[Internal.SlotIndex] THEN
						Internal.Fubs.ShCopyUserData[Internal.SlotIndex].Execute := FALSE;
                        Internal.Fubs.RoutedMoveAbs[Internal.SlotIndex].Axis := ADR(Internal.SlotShuttleRefs[Internal.SlotIndex]);
                        Internal.Fubs.RoutedMoveAbs[Internal.SlotIndex].Sector := TargetDetails.SectorReference;
                        Internal.Fubs.RoutedMoveAbs[Internal.SlotIndex].Position := TargetDetails.Position;
                        Internal.Fubs.RoutedMoveAbs[Internal.SlotIndex].Velocity := MotionParameters.Velocity;
                        Internal.Fubs.RoutedMoveAbs[Internal.SlotIndex].Acceleration := MotionParameters.Acceleration;
                        Internal.Fubs.RoutedMoveAbs[Internal.SlotIndex].Deceleration := MotionParameters.Deceleration;
                        Internal.Fubs.RoutedMoveAbs[Internal.SlotIndex].AdvancedParameters.StartDirection := mcDIR_UNDEFINED;
                        Internal.Fubs.RoutedMoveAbs[Internal.SlotIndex].AdvancedParameters.EndDirection := mcDIR_POSITIVE;
                        Internal.Fubs.RoutedMoveAbs[Internal.SlotIndex].AdvancedParameters.ShuttleOrientation := mcDIR_UNDEFINED;
                        Internal.Fubs.RoutedMoveAbs[Internal.SlotIndex].Execute := TRUE;
					END_IF
				END_FOR
				Internal.SlotsState := SLOTS_CONFIRM_RELEASE;
			END_IF

		SLOTS_CONFIRM_RELEASE:
			// Every cycle, count the number of slots that have finished sending the shuttle or are disabled. If the count = MAX_NUM_SLOTS, then all slots are done
			Internal.TempShuttleReleased := 0;
			FOR Internal.SlotIndex:=1 TO MAX_NUM_SLOTS DO
				IF (Internal.Fubs.RoutedMoveAbs[Internal.SlotIndex].Active OR
					NOT Internal.SlotEnabled[Internal.SlotIndex]) THEN
					Internal.TempShuttleReleased := Internal.TempShuttleReleased + 1;
				END_IF
			END_FOR
			// If the tooling is not clear at this point, raise an error and stop all shuttles
			IF NOT ToolingClear THEN
				FOR Internal.SlotIndex:=1 TO MAX_NUM_SLOTS DO
					Internal.Fubs.RoutedMoveAbs[Internal.SlotIndex].Execute := FALSE;
				END_FOR
				Internal.Fubs.SecStop.Execute := TRUE;
				Error := TRUE;
				ErrorText := 'Tooling is not clear during release';
				Internal.SlotsState := SLOTS_ERROR;
			// If the FUB was disabled or recovery was requested go to the disabled state
			ELSIF NOT(Enable AND NOT Recover) THEN
				FOR Internal.SlotIndex:=1 TO MAX_NUM_SLOTS DO
					Internal.Fubs.RoutedMoveAbs[Internal.SlotIndex].Execute := FALSE;
				END_FOR
				Internal.SlotsState := SLOTS_DISABLED;
			// If the count = MAX_NUM_SLOTS, then all slots are done. Reset all slot commands
			ELSIF Internal.TempShuttleReleased = MAX_NUM_SLOTS THEN
				FOR Internal.SlotIndex:=1 TO MAX_NUM_SLOTS DO
					Internal.Fubs.RoutedMoveAbs[Internal.SlotIndex].Execute := FALSE;
				END_FOR
				// Reset the slot index to the farthest slot
				Internal.SlotIndex := Internal.FarthestSlot;
				Internal.SlotsState := SLOTS_WAIT_FOR_QUEUE;
			END_IF

		SLOTS_SEND_ON:
			// If the tooling is no longer clear at this point, raise an error and stop all shuttles
			IF NOT ToolingClear THEN
				Internal.Fubs.RoutedMoveAbs[Internal.SlotIndex].Execute := FALSE;
				Internal.Fubs.SecStop.Execute := TRUE;
				Error := TRUE;
				ErrorText := 'Tooling is not clear during slot bypass';
				Internal.SlotsState := SLOTS_ERROR;
			// If the FUB was disabled or recovery was requested go to the disabled state
			ELSIF NOT(Enable AND NOT Recover) THEN
				FillingSlots := FALSE;
				Internal.Fubs.RoutedMoveAbs[Internal.SlotIndex].Execute := FALSE;
				Internal.SlotsState := SLOTS_DISABLED;
			// If the move is active, clear the command and check the queue
			ELSIF Internal.Fubs.RoutedMoveAbs[Internal.SlotIndex].Active THEN
				Internal.Fubs.RoutedMoveAbs[Internal.SlotIndex].Execute := FALSE;
				Internal.SlotsState := SLOTS_WAIT_FOR_QUEUE;
			END_IF

		SLOTS_RECOVERING:
			// If enable drops, recovery will be aborted
			IF NOT Enable THEN
				Internal.SlotsState := SLOTS_DISABLED;
			// When recovery is finished, determine what to do next
			ELSIF RecoveryDone AND NOT Recover THEN
				// The recovery possibly put shuttles in slots. The slot index will reflect this
				IF Internal.SlotIndex = 0 THEN
					// All slots had shuttles sent to them
					Internal.RecoveryFilledSlots := TRUE;
				ELSIF Internal.SlotIndex = Internal.FarthestSlot THEN
					// No slots had shuttles sent to them
				ELSE
					// Some slots had shuttles sent to them, so set FillingSlots
					FillingSlots := TRUE;
				END_IF
				Internal.SlotsState := SLOTS_DISABLED;
			END_IF

		SLOTS_ERROR:
            Internal.TempUserdataWritten := FALSE;
			// If the reset is true, reset all FUBs and outputs
			IF ErrorReset THEN
				FillingSlots := FALSE;
				SlotsFilled := FALSE;
				Internal.SlotIndex := Internal.FarthestSlot;
				Internal.SlotsState := SLOTS_DISABLED;
			END_IF

	END_CASE

	// RECOVERY ----------------------------------------------------------------------------------------------------------------------------------------------------------
	CASE Internal.RecoveryState OF

		RECOV_DISABLED:
			// Wait for the recover command, the tooling to be clear, and the buffer and slots to be in the recovering state before recovering
			IF Enable AND Recover AND ToolingClear AND (Internal.BufferState = BUF_RECOVERING) AND (Internal.SlotsState = SLOTS_RECOVERING) AND NOT Error THEN
				// Clear all flags and fubs for a fresh start
				FillingSlots := FALSE;
				SlotsFilled := FALSE;
				Internal.RecoveryFilledSlots := FALSE;
				Internal.Fubs.SecStop.Execute := FALSE;
				Internal.Fubs.SecGetShuttleSel.Enable := FALSE;
				Internal.Fubs.ShSwitchSector.Execute := FALSE;
				FOR Internal.FubIndex:=0 TO MAX_NUM_SLOTS DO
					Internal.Fubs.ShReadInfo[Internal.FubIndex].Enable := FALSE;
                    Internal.Fubs.ElasticMoveAbs[Internal.FubIndex].Execute := FALSE;
					Internal.Fubs.RoutedMoveAbs[Internal.FubIndex].Execute := FALSE;
					Internal.Fubs.ShCopyUserData[Internal.FubIndex].Execute := FALSE;
				END_FOR
				Internal.RecoveryState := RECOV_FIND_ALL_1;
			END_IF

		RECOV_FIND_ALL_1:
			// If the tooling is no longer clear, raise an error and stop all shuttles
			IF NOT ToolingClear THEN
				Internal.Fubs.SecStop.Execute := TRUE;
				Error := TRUE;
				ErrorText := 'Tooling is not clear during recovery';
				Internal.RecoveryState := RECOV_ERROR;
			// If the enable is lowered, return to the disabled state
			ELSIF NOT Enable THEN
				Internal.RecoveryState := RECOV_DISABLED;
			END_IF
			// Using the sector reference of this station's buffer, find all shuttles on the station's sector from the start to the end
			Internal.RecoveryIndex := 0;
			Internal.Fubs.SecGetShuttleSel.Sector := SelfDetails[0].SectorReference;
            Internal.Fubs.SecGetShuttleSel.Mode := mcACPTRAK_SEARCH_FORWARD;
            Internal.Fubs.SecGetShuttleSel.AdvancedParameters.StartPosition := 0.0;
            Internal.Fubs.SecGetShuttleSel.AdvancedParameters.EndPosition := 0.0;
            Internal.Fubs.SecGetShuttleSel.AdvancedParameters.SelectionMode := mcACPTRAK_GET_SH_ALL;
            Internal.Fubs.SecGetShuttleSel.AdvancedParameters.VirtualSelectionMode := mcACPTRAK_GET_SH_VIRT_ALL;
			Internal.Fubs.SecGetShuttleSel.Enable := TRUE;
			Internal.RecoveryState := RECOV_PUT_ON_SECT;

		RECOV_PUT_ON_SECT:
			// If the tooling is no longer clear, raise an error and stop all shuttles
			IF NOT ToolingClear THEN
				Internal.Fubs.SecGetShuttleSel.Enable := FALSE;
				Internal.Fubs.SecStop.Execute := TRUE;
				Error := TRUE;
				ErrorText := 'Tooling is not clear during recovery';
				Internal.RecoveryState := RECOV_ERROR;
			// If the enable is lowered, return to the disabled state
			ELSIF NOT Enable THEN
				Internal.Fubs.SecGetShuttleSel.Enable := FALSE;
				Internal.RecoveryState := RECOV_DISABLED;
			// Once the shuttles on the sector have been found, decide what to do
			ELSIF Internal.Fubs.SecGetShuttleSel.Valid THEN
				// If there are no shuttles, then recovery is done
				IF Internal.Fubs.SecGetShuttleSel.TotalCount = 0 THEN
					Internal.Fubs.SecGetShuttleSel.Enable := FALSE;
					// Raise the signal of recovery completing
					RecoveryDone := TRUE;
					// Change the slot index to reflect the current state of the slots after recovery
					Internal.SlotIndex := Internal.FarthestSlot;
					Internal.RecoveryState := RECOV_DONE;
				// If there are shuttles, send them backward to the start of the sector plus increments of the shuttle width
				ELSE
					Internal.Fubs.SecGetShuttleSel.Next := FALSE;
					Internal.Fubs.ShSwitchSector.Axis := ADR(Internal.Fubs.SecGetShuttleSel.Axis);
					Internal.Fubs.ShSwitchSector.Sector := SelfDetails[0].SectorReference;
					Internal.Fubs.ShSwitchSector.Execute := TRUE;
					Internal.RecoveryState := RECOV_CONFIRM_PUT_ON_SECT;
				END_IF
			END_IF

        RECOV_CONFIRM_PUT_ON_SECT:
            // If the tooling is no longer clear, raise an error and stop all shuttles
			IF NOT ToolingClear THEN
				Internal.Fubs.ShSwitchSector.Execute := FALSE;
				Internal.Fubs.SecGetShuttleSel.Enable := FALSE;
				Internal.Fubs.SecStop.Execute := TRUE;
				Error := TRUE;
				ErrorText := 'Tooling is not clear during recovery';
				Internal.RecoveryState := RECOV_ERROR;
			// If the enable is lowered, return to the disabled state
			ELSIF NOT Enable THEN
				Internal.Fubs.SecGetShuttleSel.Enable := FALSE;
				Internal.RecoveryState := RECOV_DISABLED;
            ELSIF Internal.Fubs.ShSwitchSector.Done THEN
                Internal.Fubs.ShSwitchSector.Execute := FALSE;
                // If there are shuttles left, increment the index and move the next shuttle
                IF Internal.Fubs.SecGetShuttleSel.RemainingCount > 0 THEN
                    Internal.Fubs.SecGetShuttleSel.Next := TRUE;
                    Internal.RecoveryState := RECOV_PUT_ON_SECT;
                // If all shuttles have been moved backward, calculate the number of shuttles to be sent away based on the number behind the buffer and the number of active slots
                ELSE
                    Internal.Fubs.SecGetShuttleSel.Enable := FALSE;
                    Internal.Fubs.RecoveryTimer.IN := TRUE;
                    Internal.RecoveryState := RECOV_FIND_ALL_2_BUFFER;
                END_IF
            END_IF


//		RECOV_SEND_REVERSE:
//			// If the tooling is no longer clear, raise an error and stop all shuttles
//			IF NOT ToolingClear THEN
//				Internal.Fubs.ShSwitchSector.Execute := FALSE;
//				Internal.Fubs.SecGetShuttleSel.Enable := FALSE;
//				Internal.Fubs.SecStop.Execute := TRUE;
//				Error := TRUE;
//				ErrorText := 'Tooling is not clear during recovery';
//				Internal.RecoveryState := RECOV_ERROR;
//			// If the enable is lowered, return to the disabled state
//			ELSIF NOT Enable THEN
//				Internal.Fubs.SecGetShuttleSel.Enable := FALSE;
//				Internal.RecoveryState := RECOV_DISABLED;
//			// Once the shuttle is on the sector, send them backward to the start of the sector (offset by 1 mm to avoid setting off the process point)
//			ELSIF Internal.Fubs.ShSwitchSector.Done THEN
//				Internal.Fubs.ShSwitchSector.Execute := FALSE;
//				Internal.Fubs.RoutedMoveAbs[0].Axis := ADR(Internal.Fubs.SecGetShuttleSel.Axis);
//				Internal.Fubs.RoutedMoveAbs[0].Sector := SelfDetails[0].SectorReference;
//				Internal.Fubs.RoutedMoveAbs[0].Position := REVERSE_MOVE_OFFSET;
//				Internal.Fubs.RoutedMoveAbs[0].Velocity := MotionParameters.Velocity;
//				Internal.Fubs.RoutedMoveAbs[0].Acceleration := MotionParameters.Acceleration;
//				Internal.Fubs.RoutedMoveAbs[0].Deceleration := MotionParameters.Deceleration;
//				Internal.Fubs.RoutedMoveAbs[0].AdvancedParameters.StartDirection := mcDIR_UNDEFINED;
//				Internal.Fubs.RoutedMoveAbs[0].AdvancedParameters.EndDirection := mcDIR_NEGATIVE;
//				Internal.Fubs.RoutedMoveAbs[0].AdvancedParameters.ShuttleOrientation := mcDIR_UNDEFINED;
//				Internal.Fubs.RoutedMoveAbs[0].Execute := TRUE;
//				// Start monitoring the shuttle's status
//				Internal.Fubs.ShReadInfo[0].Axis := ADR(Internal.Fubs.SecGetShuttleSel.Axis);
//				Internal.Fubs.ShReadInfo[0].Enable := TRUE;
//				Internal.RecoveryState := RECOV_CONFIRM_REVERSE;
//			END_IF
//
//		RECOV_CONFIRM_REVERSE:
//			// If the tooling is no longer clear, raise an error and stop all shuttles
//			IF NOT ToolingClear THEN
//				Internal.Fubs.RoutedMoveAbs[0].Execute := FALSE;
//				Internal.Fubs.ShReadInfo[0].Enable := FALSE;
//				Internal.Fubs.SecStop.Execute := TRUE;
//				Error := TRUE;
//				ErrorText := 'Tooling is not clear during recovery';
//				Internal.RecoveryState := RECOV_ERROR;
//			// If the enable is lowered, return to the disabled state
//			ELSIF NOT Enable THEN
//				Internal.Fubs.RoutedMoveAbs[0].Execute := FALSE;
//				Internal.Fubs.ShReadInfo[0].Enable := FALSE;
//				Internal.RecoveryState := RECOV_DISABLED;
//			ELSIF Internal.Fubs.RoutedMoveAbs[0].Active THEN
//				Internal.Fubs.RoutedMoveAbs[0].Execute := FALSE;
//				Internal.Fubs.ShReadInfo[0].Enable := FALSE;
//				// If there are shuttles left, increment the index and move the next shuttle
//				IF Internal.Fubs.SecGetShuttleSel.RemainingCount > 0 THEN
//					Internal.Fubs.SecGetShuttleSel.Next := TRUE;
//					Internal.RecoveryIndex := Internal.RecoveryIndex + 1;
//					Internal.RecoveryState := RECOV_PUT_ON_SECT;
//				// If all shuttles have been moved backward, calculate the number of shuttles to be sent away based on the number behind the buffer and the number of active slots
//				ELSE
//					Internal.Fubs.SecGetShuttleSel.Enable := FALSE;
//					Internal.Fubs.RecoveryTimer.IN := TRUE;
//					Internal.RecoveryState := RECOV_FIND_ALL_2_BUFFER;
//				END_IF
//			END_IF

        RECOV_FIND_ALL_2_BUFFER:
			// If the tooling is no longer clear, raise an error and stop all shuttles
			IF NOT ToolingClear THEN
				Internal.Fubs.SecStop.Execute := TRUE;
				Internal.Fubs.RecoveryTimer.IN := FALSE;
				Error := TRUE;
				ErrorText := 'Tooling is not clear during recovery';
				Internal.RecoveryState := RECOV_ERROR;
			// If the enable is lowered, return to the disabled state
			ELSIF NOT Enable THEN
				Internal.Fubs.RecoveryTimer.IN := FALSE;
				Internal.RecoveryState := RECOV_DISABLED;
			END_IF
			IF Internal.Fubs.RecoveryTimer.Q THEN
				Internal.Fubs.RecoveryTimer.IN := FALSE;
				// Using the sector reference of this station's buffer, find all shuttles on the station's sector from the end to the start
				Internal.RecoveryIndex := Internal.FarthestSlot;
				Internal.Fubs.SecGetShuttleSel.Sector := SelfDetails[0].SectorReference;
				Internal.Fubs.SecGetShuttleSel.Mode := mcACPTRAK_SEARCH_BACKWARD;
                Internal.Fubs.SecGetShuttleSel.AdvancedParameters.StartPosition := 0.0;
                Internal.Fubs.SecGetShuttleSel.AdvancedParameters.EndPosition := 0.118; // Buffer position standardized to 0.1174 
                Internal.Fubs.SecGetShuttleSel.AdvancedParameters.SelectionMode := mcACPTRAK_GET_SH_ALL;
                Internal.Fubs.SecGetShuttleSel.AdvancedParameters.VirtualSelectionMode := mcACPTRAK_GET_SH_VIRT_ALL;
				Internal.Fubs.SecGetShuttleSel.Enable := TRUE;
				Internal.RecovBufferIndex := 0;
			END_IF
            IF Internal.Fubs.SecGetShuttleSel.Valid THEN
                Internal.BehindBuffer := Internal.Fubs.SecGetShuttleSel.TotalCount;
				Internal.Fubs.SecGetShuttleSel.Enable := FALSE;
				Internal.RecoveryState := RECOV_FIND_ALL_2;
            END_IF

        RECOV_FIND_ALL_2:
			// If the tooling is no longer clear, raise an error and stop all shuttles
			IF NOT ToolingClear THEN
				Internal.Fubs.SecStop.Execute := TRUE;
				Internal.Fubs.RecoveryTimer.IN := FALSE;
				Error := TRUE;
				ErrorText := 'Tooling is not clear during recovery';
				Internal.RecoveryState := RECOV_ERROR;
			// If the enable is lowered, return to the disabled state
			ELSIF NOT Enable THEN
				Internal.Fubs.RecoveryTimer.IN := FALSE;
				Internal.RecoveryState := RECOV_DISABLED;
			END_IF
            IF NOT Internal.Fubs.SecGetShuttleSel.Valid THEN
				Internal.RecoveryIndex := Internal.FarthestSlot;
				Internal.Fubs.SecGetShuttleSel.Sector := SelfDetails[0].SectorReference;
				Internal.Fubs.SecGetShuttleSel.Mode := mcACPTRAK_SEARCH_BACKWARD;
                Internal.Fubs.SecGetShuttleSel.AdvancedParameters.StartPosition := 0.0;
                Internal.Fubs.SecGetShuttleSel.AdvancedParameters.EndPosition := 0.0;
                Internal.Fubs.SecGetShuttleSel.AdvancedParameters.SelectionMode := mcACPTRAK_GET_SH_ALL;
                Internal.Fubs.SecGetShuttleSel.AdvancedParameters.VirtualSelectionMode := mcACPTRAK_GET_SH_VIRT_ALL;
				Internal.Fubs.SecGetShuttleSel.Enable := TRUE;
            END_IF

            IF Internal.Fubs.SecGetShuttleSel.Valid THEN
                // Only send shuttles away if there are more than can fit behind the buffer and in the slots
                IF Purge THEN
                    Internal.SendAway := Internal.Fubs.SecGetShuttleSel.TotalCount;
                ELSIF Internal.Fubs.SecGetShuttleSel.TotalCount > (Internal.ActiveSlots + Internal.BehindBuffer) THEN
                    Internal.SendAway := Internal.Fubs.SecGetShuttleSel.TotalCount - (Internal.ActiveSlots + Internal.BehindBuffer);
                ELSE
                    Internal.SendAway := 0;
                END_IF
				Internal.RecoveryState := RECOV_SEND_FORWARD;
            END_IF

		RECOV_SEND_FORWARD:
			// If the tooling is no longer clear, raise an error and stop all shuttles
			IF NOT ToolingClear THEN
				Internal.Fubs.SecGetShuttleSel.Enable := FALSE;
				Internal.Fubs.SecStop.Execute := TRUE;
				Error := TRUE;
				ErrorText := 'Tooling is not clear during recovery';
				Internal.RecoveryState := RECOV_ERROR;
			// If the enable is lowered, return to the disabled state
			ELSIF NOT Enable THEN
				Internal.Fubs.SecGetShuttleSel.Enable := FALSE;
				Internal.RecoveryState := RECOV_DISABLED;
			// Send all shuttles forward
			ELSIF Internal.Fubs.SecGetShuttleSel.Valid THEN
				Internal.Fubs.SecGetShuttleSel.Next := FALSE;
				// If there are shuttles to be sent away, send them back to the buffer in the positive direction (do a lap)
				// If this is a purge, send the shuttles the stations target instead
				// Not setting the userdata means the shuttle will do a lap
				IF Internal.SendAway > 0 THEN
                    Internal.Fubs.RoutedMoveAbs[0].Axis := ADR(Internal.Fubs.SecGetShuttleSel.Axis);
                    Internal.Fubs.RoutedMoveAbs[0].Sector := TargetDetails.SectorReference;
                    Internal.Fubs.RoutedMoveAbs[0].Position := TargetDetails.Position;
                    Internal.Fubs.RoutedMoveAbs[0].Velocity := MotionParameters.Velocity;
                    Internal.Fubs.RoutedMoveAbs[0].Acceleration := MotionParameters.Acceleration;
                    Internal.Fubs.RoutedMoveAbs[0].Deceleration := MotionParameters.Deceleration;
                    Internal.Fubs.RoutedMoveAbs[0].AdvancedParameters.StartDirection := mcDIR_UNDEFINED;
                    Internal.Fubs.RoutedMoveAbs[0].AdvancedParameters.EndDirection := mcDIR_POSITIVE;
                    Internal.Fubs.RoutedMoveAbs[0].AdvancedParameters.ShuttleOrientation := mcDIR_UNDEFINED;
                    Internal.Fubs.RoutedMoveAbs[0].Execute := TRUE;
					// Read shuttles userdata for use in writing the recovered flag back to it without changing other data
					Internal.Fubs.ShCopyUserData[0].Axis := ADR(Internal.Fubs.SecGetShuttleSel.Axis);
					Internal.Fubs.ShCopyUserData[0].DataAddress := ADR(UserData[0]);
					Internal.Fubs.ShCopyUserData[0].DataSize := SIZEOF(UserData[0]);
					Internal.Fubs.ShCopyUserData[0].Mode := mcACPTRAK_USERDATA_GET;
					Internal.Fubs.ShCopyUserData[0].Execute := TRUE;
					// Start monitoring the shuttle's status
					Internal.Fubs.ShReadInfo[0].Axis := ADR(Internal.Fubs.SecGetShuttleSel.Axis);
					Internal.Fubs.ShReadInfo[0].Enable := TRUE;
					Internal.RecoveryState := RECOV_CONFIRM_FORWARD;
					// If there are slots that haven't been filled, fill them, add them to the shuttle list, and read the userdata
				ELSIF Internal.RecoveryIndex > 0 THEN
					// Only send to the slot if it is enabled. Otherwise decrement i
					IF Internal.SlotEnabled[Internal.RecoveryIndex] THEN
						// Add shuttle to list
						Internal.SlotShuttleRefs[Internal.RecoveryIndex] := Internal.Fubs.SecGetShuttleSel.Axis;
						// Read shuttles userdata for keeping in the slot's userdata
						Internal.Fubs.ShCopyUserData[Internal.RecoveryIndex].Axis := ADR(Internal.SlotShuttleRefs[Internal.RecoveryIndex]);
						Internal.Fubs.ShCopyUserData[Internal.RecoveryIndex].DataAddress := ADR(UserData[Internal.RecoveryIndex]);
						Internal.Fubs.ShCopyUserData[Internal.RecoveryIndex].DataSize := SIZEOF(UserData[Internal.RecoveryIndex]);
						Internal.Fubs.ShCopyUserData[Internal.RecoveryIndex].Mode := mcACPTRAK_USERDATA_GET;
						Internal.Fubs.ShCopyUserData[Internal.RecoveryIndex].Execute := TRUE;
						// Read shuttles userdata for use in writing the recovered flag back to it without changing other data
						Internal.Fubs.ShCopyUserData[0].Axis := ADR(Internal.Fubs.SecGetShuttleSel.Axis);
						Internal.Fubs.ShCopyUserData[0].DataAddress := ADR(UserData[0]);
						Internal.Fubs.ShCopyUserData[0].DataSize := SIZEOF(UserData[0]);
						Internal.Fubs.ShCopyUserData[0].Mode := mcACPTRAK_USERDATA_GET;
						Internal.Fubs.ShCopyUserData[0].Execute := TRUE;
						// Send shuttle to slot
						Internal.Fubs.ElasticMoveAbs[Internal.RecoveryIndex].Axis := ADR(Internal.SlotShuttleRefs[Internal.RecoveryIndex]);
						Internal.Fubs.ElasticMoveAbs[Internal.RecoveryIndex].Position := SelfDetails[Internal.RecoveryIndex].Position;
						Internal.Fubs.ElasticMoveAbs[Internal.RecoveryIndex].Velocity := MotionParameters.Velocity;
						Internal.Fubs.ElasticMoveAbs[Internal.RecoveryIndex].Acceleration := MotionParameters.Acceleration;
						Internal.Fubs.ElasticMoveAbs[Internal.RecoveryIndex].Deceleration := MotionParameters.Deceleration;
						Internal.Fubs.ElasticMoveAbs[Internal.RecoveryIndex].Execute := TRUE;
						// Start monitoring the shuttle's status
						Internal.Fubs.ShReadInfo[Internal.RecoveryIndex].Axis := ADR(Internal.Fubs.SecGetShuttleSel.Axis);
						Internal.Fubs.ShReadInfo[Internal.RecoveryIndex].Enable := TRUE;
						Internal.RecoveryState := RECOV_CONFIRM_FORWARD;
					ELSE
						Internal.RecoveryIndex := Internal.RecoveryIndex - 1;
					END_IF
				// The remaining shuttles are destined for the buffer. Send them there and add them to the queue
				ELSE
//					Internal.Fubs.RoutedMoveAbs[0].Axis := ADR(Internal.Fubs.SecGetShuttleSel.Axis);
//					Internal.Fubs.RoutedMoveAbs[0].Sector := SelfDetails[0].SectorReference;
//					Internal.Fubs.RoutedMoveAbs[0].Position := SelfDetails[0].Position;
//					Internal.Fubs.RoutedMoveAbs[0].Velocity := MotionParameters.Velocity;
//					Internal.Fubs.RoutedMoveAbs[0].Acceleration := MotionParameters.Acceleration;
//					Internal.Fubs.RoutedMoveAbs[0].Deceleration := MotionParameters.Deceleration;
//					Internal.Fubs.RoutedMoveAbs[0].AdvancedParameters.StartDirection := mcDIR_UNDEFINED;
//					Internal.Fubs.RoutedMoveAbs[0].AdvancedParameters.EndDirection := mcDIR_POSITIVE;
//					Internal.Fubs.RoutedMoveAbs[0].AdvancedParameters.ShuttleOrientation := mcDIR_UNDEFINED;
//					Internal.Fubs.RoutedMoveAbs[0].Execute := TRUE;
					tbBufferAddSh(ADR(Internal.StationBuffer),ADR(Internal.Fubs.SecGetShuttleSel.Axis));
					// Read shuttles userdata for use in writing the recovered flag back to it without changing other data
					Internal.Fubs.ShCopyUserData[0].Axis := ADR(Internal.Fubs.SecGetShuttleSel.Axis);
					Internal.Fubs.ShCopyUserData[0].DataAddress := ADR(UserData[0]);
					Internal.Fubs.ShCopyUserData[0].DataSize := SIZEOF(UserData[0]);
					Internal.Fubs.ShCopyUserData[0].Mode := mcACPTRAK_USERDATA_GET;
					Internal.Fubs.ShCopyUserData[0].Execute := TRUE;
					// Start monitoring the shuttle's status
					Internal.Fubs.ShReadInfo[0].Axis := ADR(Internal.Fubs.SecGetShuttleSel.Axis);
					Internal.Fubs.ShReadInfo[0].Enable := TRUE;
					Internal.RecovBufferIndex := Internal.RecovBufferIndex + 1;
					Internal.RecoveryState := RECOV_CONFIRM_FORWARD;
				END_IF
			END_IF

		RECOV_CONFIRM_FORWARD:
			// If the tooling is no longer clear, raise an error and stop all shuttles
			IF NOT ToolingClear THEN
				Internal.Fubs.RoutedMoveAbs[0].Execute := FALSE;
				Internal.Fubs.ShCopyUserData[Internal.RecoveryIndex].Execute := FALSE;
				Internal.Fubs.ShReadInfo[0].Enable := FALSE;
				Internal.Fubs.SecStop.Execute := TRUE;
				Error := TRUE;
				ErrorText := 'Tooling is not clear during recovery';
				Internal.RecoveryState := RECOV_ERROR;
			// If the enable is lowered, return to the disabled state
			ELSIF NOT Enable THEN
				Internal.Fubs.RoutedMoveAbs[0].Execute := FALSE;
				Internal.Fubs.RoutedMoveAbs[Internal.RecoveryIndex].Execute := FALSE;
				Internal.Fubs.ShCopyUserData[Internal.RecoveryIndex].Execute := FALSE;
				Internal.Fubs.ShReadInfo[0].Enable := FALSE;
				Internal.RecoveryState := RECOV_DISABLED;
			// Once one of the following conditions is true...
			// -----------------------------------------------
			// 1) If the shuttle was sent away and the routed absolute move is active
			//    and reading the userdata for flagging's sake is done
			ELSIF ((Internal.SendAway > 0) AND
				(Internal.Fubs.RoutedMoveAbs[0].Execute) AND
				Internal.Fubs.RoutedMoveAbs[0].Active AND
				    Internal.Fubs.ShCopyUserData[0].Done) THEN
				Internal.Fubs.RoutedMoveAbs[0].Execute := FALSE;
				Internal.Fubs.ShCopyUserData[0].Execute := FALSE;
				Internal.Fubs.ShReadInfo[0].Enable := FALSE;
				Internal.SendAway := Internal.SendAway - 1;
					UserData[0].Destination := TargetDetails;
				Internal.RecoveryState := RECOV_MARK_RECOVERED;
			// 2) If the shuttle was sent to a slot and the routed absolute move is active
			//    and the reading of userdata for the slot and reading the userdata for flagging's sake are done
			ELSIF ((Internal.RecoveryIndex > 0) AND
				    (Internal.Fubs.ElasticMoveAbs[Internal.RecoveryIndex].Active OR Internal.Fubs.ElasticMoveAbs[Internal.RecoveryIndex].Active) AND
				    Internal.Fubs.ShCopyUserData[Internal.RecoveryIndex].Done AND
					Internal.Fubs.ShCopyUserData[0].Done) THEN
				// Note: Not resetting the routed move or ShReadInfo on purpose -JRN
                Internal.Fubs.ShCopyUserData[0].Execute := FALSE;
				Internal.Fubs.ShCopyUserData[Internal.RecoveryIndex].Execute := FALSE;
				UserData[0].Destination := SelfDetails[0];
				Internal.RecoveryIndex := Internal.RecoveryIndex - 1;
				// With the new recovery index, only run the check if it is nonzero
				IF Internal.RecoveryIndex <> 0 THEN
					// If the related slot is disabled, decrement again. If the recovery index becomes zero, break out
					WHILE NOT Internal.SlotEnabled[Internal.RecoveryIndex] DO
						Internal.RecoveryIndex := Internal.RecoveryIndex - 1;
						IF Internal.RecoveryIndex = 0 THEN
							EXIT;
						END_IF
					END_WHILE
				END_IF
				Internal.RecoveryState := RECOV_MARK_RECOVERED;
			// 3) If the shuttle was sent to the buffer and the shuttle move is active
			//    and reading the userdata for flagging's sake is done
			ELSIF ((Internal.RecoveryIndex = 0) AND
				    Internal.Fubs.ShCopyUserData[0].Done) THEN
				Internal.Fubs.ShCopyUserData[0].Execute := FALSE;
				Internal.Fubs.ShReadInfo[0].Enable := FALSE;
				UserData[0].Destination := SelfDetails[0];
				Internal.RecoveryState := RECOV_MARK_RECOVERED;
			END_IF

		RECOV_MARK_RECOVERED:
			// Set the recovered flag true
			UserData[0].Recovered := TRUE;
			// If the shuttle has no destination information, the shuttle is being sent away or purged on startup
			IF UserData[0].Destination.SectorReference = 0 THEN
				UserData[0].Destination := TargetDetails;
			END_IF
			// Write to the shuttle's userdata
			Internal.Fubs.ShCopyUserData[0].Axis := ADR(Internal.Fubs.SecGetShuttleSel.Axis);
			Internal.Fubs.ShCopyUserData[0].DataAddress := ADR(UserData[0]);
			Internal.Fubs.ShCopyUserData[0].DataSize := SIZEOF(UserData[0]);
			Internal.Fubs.ShCopyUserData[0].Mode := mcACPTRAK_USERDATA_SET;
			Internal.Fubs.ShCopyUserData[0].Execute := TRUE;
			Internal.RecoveryState := RECOV_CHECK_REMAINING;

		RECOV_CHECK_REMAINING:
			// If the tooling is no longer clear, raise an error and stop all shuttles
			IF NOT ToolingClear THEN
				Internal.Fubs.ShCopyUserData[0].Execute := FALSE;
				Internal.Fubs.SecStop.Execute := TRUE;
				Error := TRUE;
				ErrorText := 'Tooling is not clear during recovery';
				Internal.RecoveryState := RECOV_ERROR;
			// If the enable is lowered, return to the disabled state
			ELSIF NOT Enable THEN
				Internal.Fubs.ShCopyUserData[0].Execute := FALSE;
				Internal.RecoveryState := RECOV_DISABLED;
			// If the writing of the userdata is complete, then check if there are more shuttles to recover
			ELSIF Internal.Fubs.ShCopyUserData[0].Done THEN
				Internal.Fubs.ShCopyUserData[0].Execute := FALSE;
				// If there are shuttles left, move the next shuttle
				IF Internal.Fubs.SecGetShuttleSel.RemainingCount > 0 THEN
					Internal.Fubs.SecGetShuttleSel.Next := TRUE;
					Internal.RecoveryState := RECOV_SEND_FORWARD;
				// If all shuttles have been moved forward,the recovery is done
				ELSE
					Internal.Fubs.SecGetShuttleSel.Enable := FALSE;
					// Raise the signal of recovery completing
					RecoveryDone := TRUE;
					// Change the slot index to reflect the current state of the slots after recovery
					Internal.SlotIndex := Internal.RecoveryIndex;
					Internal.BehindBuffer := 0;
					Internal.RecoveryState := RECOV_DONE;
				END_IF
			END_IF

		RECOV_DONE:
			// Wait for the recover signal to reset before going to the disabled state
			IF NOT Recover THEN
				RecoveryDone := FALSE;
				Internal.RecoveryState := RECOV_DISABLED;
			END_IF

		RECOV_ERROR:
			// If the reset command is set, reset the FUBs
			IF ErrorReset THEN
				Recover := FALSE;
				RecoveryDone := FALSE;
				Internal.RecoveryState := RECOV_DISABLED;
			END_IF
	END_CASE

	// Call internal FUBs
	Internal.Fubs.TrgPointEnable();
	Internal.Fubs.TrgPointGetInfo();
	Internal.Fubs.SecStop();
	Internal.Fubs.SecGetShuttleSel();
	Internal.Fubs.RecoveryTimer();
	Internal.Fubs.ShSwitchSector();
	FOR Internal.FubIndex:=0 TO MAX_NUM_SLOTS DO
		Internal.Fubs.ShReadInfo[Internal.FubIndex]();
        Internal.Fubs.ElasticMoveAbs[Internal.FubIndex]();
		Internal.Fubs.RoutedMoveAbs[Internal.FubIndex]();
		Internal.Fubs.ShCopyUserData[Internal.FubIndex]();
	END_FOR


/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//  Error Handling
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

    IF Internal.Fubs.TrgPointEnable.Error THEN
        Error := TRUE;
        ErrorText := 'Error on Internal.Fubs.TrgPointEnable FUB';
    ELSIF Internal.Fubs.TrgPointGetInfo.Error THEN
        Error := TRUE;
        ErrorText := 'Error on Internal.Fubs.TrgPointGetInfo FUB';
    ELSIF Internal.Fubs.SecStop.Error THEN
        Error := TRUE;
        ErrorText := 'Error on Internal.Fubs.SecStop FUB';
    ELSIF Internal.Fubs.SecGetShuttleSel.Error THEN
        Error := TRUE;
        ErrorText := 'Error on Internal.Fubs.SecGetShuttleSel FUB';
    ELSIF Internal.Fubs.ShSwitchSector.Error THEN
        Error := TRUE;
        ErrorText := 'Error on Internal.Fubs.ShSwitchSector FUB';
    END_IF
	FOR Internal.FubIndex:=0 TO MAX_NUM_SLOTS DO
		IF Internal.Fubs.ShReadInfo[Internal.FubIndex].Error THEN
            Error := TRUE;
            ErrorText := 'Error on Internal.Fubs.ShReadInfo FUB';
		ELSIF Internal.Fubs.ElasticMoveAbs[Internal.FubIndex].Error THEN
            Error := TRUE;
            ErrorText := 'Error on Internal.Fubs.ElasticMoveAbs FUB';
		ELSIF Internal.Fubs.RoutedMoveAbs[Internal.FubIndex].Error THEN
            Error := TRUE;
            ErrorText := 'Error on Internal.Fubs.RoutedMoveAbs FUB';
		ELSIF Internal.Fubs.ShCopyUserData[Internal.FubIndex].Error THEN
            Error := TRUE;
            ErrorText := 'Error on Internal.Fubs.ShCopyUserData FUB';
        END_IF
	END_FOR

    IF Error THEN
        IF Internal.BufferState <> BUF_DISABLED THEN
            Internal.BufferState := BUF_ERROR;
        END_IF
        IF Internal.SlotsState <> SLOTS_DISABLED THEN
            Internal.SlotsState := SLOTS_ERROR;
        END_IF
        IF Internal.RecoveryState <> RECOV_DISABLED THEN
            Internal.RecoveryState := RECOV_ERROR;
        END_IF
    END_IF

	IF ErrorReset THEN
		// If the station is in error, then reste all FUBs
		IF Error THEN
			Internal.Fubs.TrgPointEnable.Enable := FALSE;
			Internal.Fubs.TrgPointGetInfo.Execute := FALSE;
			Internal.Fubs.SecStop.Execute := FALSE;
			Internal.Fubs.SecGetShuttleSel.Enable := FALSE;
			Internal.Fubs.RecoveryTimer.IN := FALSE;
			Internal.Fubs.ShSwitchSector.Execute := FALSE;
			FOR Internal.FubIndex:=0 TO MAX_NUM_SLOTS DO
				Internal.Fubs.ShReadInfo[Internal.FubIndex].Enable := FALSE;
				Internal.Fubs.ElasticMoveAbs[Internal.FubIndex].Execute := FALSE;
				Internal.Fubs.RoutedMoveAbs[Internal.FubIndex].Execute := FALSE;
				Internal.Fubs.ShCopyUserData[Internal.FubIndex].Execute := FALSE;
			END_FOR
		END_IF
		// Reset the error reset command and clear the error flag and string
        ErrorReset := FALSE;
        Error := FALSE;
        ErrorText := '';
    END_IF


END_FUNCTION_BLOCK