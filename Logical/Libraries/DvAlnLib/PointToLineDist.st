(*********************************************************************************
 * Copyright: B&R Industrial Automation GmbH 
 * Author:    nealj 
 * Created:   August 16, 2023/11:35 AM 
 * This function calculates and returns the distance between a point and a line
 *********************************************************************************)

FUNCTION PointToLineDist

	//      (LX1,LY1)
	//          <>
	//           \\                           (PX,PY)
	//            \\                            <>
	//             \\                       ,
	//              \\             D    ,
	//               \\             ,
	//                \\        ,
	//                 \\   ,
	//                  \\
	//                   \\
	//                    \\
	//                     \\
	//                      <> 
	//                   (LX2,LY2)
	// 
	// VARIABLES:
	// ----------
	// * PX is the X coordinate of the point
	// * PY is the Y coordinate of the point
	// * LX1 is the X coordinate of the first point
	// * LY1 is the Y coordinate of the first point
	// * LX2 is the X coordinate of the second point
	// * LY2 is the Y coordinate of the second point
	//
	// EQUATION:
	// ---------
	//
	//       |                                                             |
	//       | ( LX2 - LX1 ) * ( LY1 - PY ) - ( LX1 - PX ) * ( LY2 - LY1 ) |
	//       |                                                             |
	//     -------------------------------------------------------------------
	//            _____________________________________
	//        \  /              2                2
	//         \/  ( LX2 - LX1 )  + ( LY2 - LY1 )
	//
	//
	// PX  = P.Pos.X
	// PY  = P.Pos.Y
	// LX1 = L1.Pos.X
	// LY1 = L1.Pos.Y
	// LX2 = L2.Pos.X
	// LY2 = L2.Pos.Y	
	
	Distance := (ABS( (L2.Pos.X - L1.Pos.X)*(L1.Pos.Y - P.Pos.Y) - (L1.Pos.X - P.Pos.X)*(L2.Pos.Y - L1.Pos.Y) )) / (SQRT( EXPT((L2.Pos.X - L1.Pos.X),2) + EXPT((L2.Pos.Y - L1.Pos.Y),2) ));
	PointToLineDist := Distance;
	
END_FUNCTION