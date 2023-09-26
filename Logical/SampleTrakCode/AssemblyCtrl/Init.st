

PROGRAM _INIT
	
	// Set up assembly FUBs
	AsmPowerOn.Assembly := ADR(gAssembly_1);
	AsmPowerOff.Assembly := ADR(gAssembly_1);
	AsmReadInfo.Assembly := ADR(gAssembly_1);
	AsmReadStatus.Assembly := ADR(gAssembly_1);
	AsmGetShuttle.Assembly := ADR(gAssembly_1);
	AsmStop.Assembly := ADR(gAssembly_1);
	AsmStop.StopMode := mcSTOPMODE_JERK_LIMIT;
	
	//Set up shuttle spawning FUB
	SecAddShuttle.Sector := ADR(SEC_MainLoop);
	SecAddShuttle.Position := 0.00;
	
	// Set motion parameters
	MotionParameters.Velocity     := 1.0;
	MotionParameters.Acceleration := 40.0;
	MotionParameters.Deceleration := 40.0;

	// List all segment references
	SegmentRefs[1] := ADR(SEG_001);
	SegmentRefs[2] := ADR(SEG_002);
	SegmentRefs[3] := ADR(SEG_003);
	SegmentRefs[4] := ADR(SEG_004);
	SegmentRefs[5] := ADR(SEG_005);
	SegmentRefs[6] := ADR(SEG_006);
	SegmentRefs[7] := ADR(SEG_007);
	SegmentRefs[8] := ADR(SEG_008);
	SegmentRefs[9] := ADR(SEG_009);
	SegmentRefs[10] := ADR(SEG_010);
	SegmentRefs[11] := ADR(SEG_011);
	SegmentRefs[12] := ADR(SEG_012);
	SegmentRefs[13] := ADR(SEG_013);
	SegmentRefs[14] := ADR(SEG_014);
	SegmentRefs[15] := ADR(SEG_015);
	SegmentRefs[16] := ADR(SEG_016);
	SegmentRefs[17] := ADR(SEG_017);
	SegmentRefs[18] := ADR(SEG_018);
	SegmentRefs[19] := ADR(SEG_019);
	SegmentRefs[20] := ADR(SEG_020);
	SegmentRefs[21] := ADR(SEG_021);
	SegmentRefs[22] := ADR(SEG_022);
	SegmentRefs[23] := ADR(SEG_023);
	SegmentRefs[24] := ADR(SEG_024);
	SegmentRefs[25] := ADR(SEG_025);
	SegmentRefs[26] := ADR(SEG_026);
	SegmentRefs[27] := ADR(SEG_027);
	SegmentRefs[28] := ADR(SEG_028);
	SegmentRefs[29] := ADR(SEG_029);
	SegmentRefs[30] := ADR(SEG_030);
	SegmentRefs[31] := ADR(SEG_031);
	SegmentRefs[32] := ADR(SEG_032);
	SegmentRefs[33] := ADR(SEG_033);
	SegmentRefs[34] := ADR(SEG_034);
	SegmentRefs[35] := ADR(SEG_035);
	SegmentRefs[36] := ADR(SEG_036);
	SegmentRefs[37] := ADR(SEG_037);
	SegmentRefs[38] := ADR(SEG_038);
	SegmentRefs[39] := ADR(SEG_039);
	SegmentRefs[40] := ADR(SEG_040);
	SegmentRefs[41] := ADR(SEG_041);
	SegmentRefs[42] := ADR(SEG_042);
	SegmentRefs[43] := ADR(SEG_043);
	SegmentRefs[44] := ADR(SEG_044);
	SegmentRefs[45] := ADR(SEG_045);
	SegmentRefs[46] := ADR(SEG_046);
	SegmentRefs[47] := ADR(SEG_047);
	SegmentRefs[48] := ADR(SEG_048);
	SegmentRefs[49] := ADR(SEG_049);
	SegmentRefs[50] := ADR(SEG_050);
	SegmentRefs[51] := ADR(SEG_051);
	SegmentRefs[52] := ADR(SEG_052);
	SegmentRefs[53] := ADR(SEG_053);
	SegmentRefs[54] := ADR(SEG_054);
	SegmentRefs[55] := ADR(SEG_055);
	SegmentRefs[56] := ADR(SEG_056);
	SegmentRefs[57] := ADR(SEG_057);
	SegmentRefs[58] := ADR(SEG_058);
	SegmentRefs[59] := ADR(SEG_059);
	SegmentRefs[60] := ADR(SEG_060);
	SegmentRefs[61] := ADR(SEG_061);
	SegmentRefs[62] := ADR(SEG_062);
	SegmentRefs[63] := ADR(SEG_063);
	SegmentRefs[64] := ADR(SEG_064);
	SegmentRefs[65] := ADR(SEG_065);
	SegmentRefs[66] := ADR(SEG_066);
	SegmentRefs[67] := ADR(SEG_067);
	SegmentRefs[68] := ADR(SEG_068);
	SegmentRefs[69] := ADR(SEG_069);
	SegmentRefs[70] := ADR(SEG_070);
	SegmentRefs[71] := ADR(SEG_071);
	SegmentRefs[72] := ADR(SEG_072);
	SegmentRefs[73] := ADR(SEG_073);
	SegmentRefs[74] := ADR(SEG_074);
	SegmentRefs[75] := ADR(SEG_075);
	SegmentRefs[76] := ADR(SEG_076);
	SegmentRefs[77] := ADR(SEG_077);
	SegmentRefs[78] := ADR(SEG_078);
	SegmentRefs[79] := ADR(SEG_079);
	SegmentRefs[80] := ADR(SEG_080);
	SegmentRefs[81] := ADR(SEG_081);
	SegmentRefs[82] := ADR(SEG_082);
	SegmentRefs[83] := ADR(SEG_083);
	
	// List of all sectors (to avoid warnings in the logger)
	SEC_MainLoop;
	SEC_RedHerring_1;
	SEC_SecondLoop;
	SEC_VolcanoLeft;
	SEC_VolcanoRight;
	SEC_Squiggle;
	SEC_FlipFlop;
	SEC_RedHerring_2;
	SEC_MaintenanceLoop;
	
END_PROGRAM