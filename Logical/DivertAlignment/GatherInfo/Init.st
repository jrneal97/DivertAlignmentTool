

PROGRAM _INIT
	
	// Initialize FUBs
	AsmGetShuttleSel.Assembly := ADR(gAssembly_1);
	AsmStop.Assembly := ADR(gAssembly_1);
	AsmDeleteVirtualSh.Assembly := ADR(gAssembly_1);
	AsmDeleteVirtualSh.Command := mcACPTRAK_SH_DELETE_VIRTUAL;
	
	// Motion Pars
	VirtualMotionPars.Velocity := 5;
	VirtualMotionPars.Accel := 50;
	VirtualMotionPars.Decel := 50;
	PhysicalMotionPars.Velocity := 1;
	PhysicalMotionPars.Accel := 50;
	PhysicalMotionPars.Decel := 50;
END_PROGRAM