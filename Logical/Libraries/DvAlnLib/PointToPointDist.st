(*********************************************************************************
 * Copyright: B&R Industrial Automation GmbH 
 * Author:    nealj 
 * Created:   August 16, 2023/11:35 AM 
 * This function calculates and returns the distance between two points (2D only)
 *********************************************************************************)

FUNCTION PointToPointDist

	//           _________________________________
	//       \  /            2              2
	// D =    \/  ( X2 - X1 )  + ( Y2 - Y1 )
	//
	//
	// X1 = P1.Pos.X
	// Y1 = P1.Pos.Y
	// X2 = P2.Pos.X
	// Y2 = P2.Pos.Y
	
	Distance := SQRT( EXPT((P2.Pos.X - P1.Pos.X),2) + EXPT((P2.Pos.Y - P1.Pos.Y),2) );
	PointToPointDist := Distance;
	
END_FUNCTION