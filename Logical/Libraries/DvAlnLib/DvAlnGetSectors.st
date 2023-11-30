(*********************************************************************************
 * Copyright: B&R Industrial Automation GmbH 
 * Author:    nealj 
 * Created:   November 30, 2023/10:41 AM 
 * 
 *********************************************************************************)

FUNCTION_BLOCK DvAlnGetSectors
			
	CASE Internal.State OF
		
		GET_SEC_IDLE:
			// Wait for execute, enable the AsmGetSeg FUB
			IF Execute THEN
				Internal.AsmGetSec.Assembly := ADR(Schematic.AsmReference);
				Internal.AsmGetSec.Enable := TRUE;
				Internal.State := GET_SEC_REF;
			END_IF
					
		GET_SEC_REF:
			// Wait for validity
			IF Internal.AsmGetSec.Valid THEN
				Internal.AsmGetSec.Next := FALSE;
				// Record the secotr reference and get its info
				Internal.SecGetInfo.Sector := ADR(Internal.AsmGetSec.Sector);
				Internal.SecGetInfo.Execute := TRUE;
				// Spawn a virtual shuttle at the start of the sector
				Internal.SecAddVirtualSh.Sector := ADR(Internal.AsmGetSec.Sector);
				Internal.SecAddVirtualSh.Position := 0.0;
				Internal.SecAddVirtualSh.AdvancedParameters.Virtual := TRUE;
				Internal.SecAddVirtualSh.Execute := TRUE;
				Internal.State := GET_SEC_INFO;
			END_IF
				
		GET_SEC_INFO:
			// Wait for the SegGetInfo FUB to finish
			IF Internal.SecGetInfo.Done AND Internal.SecAddVirtualSh.Done THEN
				// Record the sector information (store them in the order they are found)
				Schematic.Sectors[Internal.AsmGetSec.TotalCount - Internal.AsmGetSec.RemainingCount - 1].Reference := Internal.AsmGetSec.Sector;
				Schematic.Sectors[Internal.AsmGetSec.TotalCount - Internal.AsmGetSec.RemainingCount - 1].Name := Internal.SecGetInfo.SectorInfo.Name;				
				Schematic.Sectors[Internal.AsmGetSec.TotalCount - Internal.AsmGetSec.RemainingCount - 1].Length := Internal.SecGetInfo.SectorInfo.Length;
				Schematic.Sectors[Internal.AsmGetSec.TotalCount - Internal.AsmGetSec.RemainingCount - 1].Type := Internal.SecGetInfo.SectorInfo.Type;
				// Reecord the virtual shuttle that was added
				Schematic.VirtualShuttles[Internal.AsmGetSec.TotalCount - Internal.AsmGetSec.RemainingCount - 1] := Internal.SecAddVirtualSh.Axis;
				// Reset the execute commands
				Internal.SecGetInfo.Execute := FALSE;
				Internal.SecAddVirtualSh.Execute := FALSE;
				// If there are more segments, iterate
				IF Internal.AsmGetSec.RemainingCount > 0 THEN
					Internal.AsmGetSec.Next := TRUE;
					Internal.State := GET_SEC_REF;
				ELSE
					Internal.AsmGetSec.Enable := FALSE;
					Internal.State := GET_SEC_DONE;
				END_IF
			END_IF
		
		GET_SEC_DONE:
			Done := TRUE;
			IF NOT Execute THEN
				Done := FALSE;
				Internal.State := GET_SEC_IDLE;
			END_IF
			
	END_CASE
	
	
	// Call FUBs
	Internal.AsmGetSec();
	Internal.SecGetInfo();
	Internal.SecAddVirtualSh();
			
END_FUNCTION_BLOCK