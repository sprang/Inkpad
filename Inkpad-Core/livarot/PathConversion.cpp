/*
 *  PathConversion.cpp
 *  nlivarot
 *
 *  Created by fred on Mon Nov 03 2003.
 *
 */

#include "Path.h"
#include "Shape.h"

void            Path::ConvertWithBackData(float treshhold)
{
	if ( descr_flags&descr_adding_bezier ) CancelBezier();
	if ( descr_flags&descr_doing_subpath ) CloseSubpath(0);
	
	SetBackData(true);
	ResetPoints(descr_nb);
	if ( descr_nb <= 0 ) return;
	float    curX,curY,curW;
	int      curP=1;
	int      lastMoveTo=0;
	
	// le moveto
	curX=(descr_data)->d.m.x;
	curY=(descr_data)->d.m.y;
	if ( (descr_data)->flags&descr_weighted ) {
		curW=(descr_data)->d.m.w;
	} else {
		curW=1;
	}
	if ( weighted ) lastMoveTo=AddPoint(curX,curY,curW,0,0.0,true); else lastMoveTo=AddPoint(curX,curY,0,0.0,true);
	
		// et le reste, 1 par 1
	while ( curP < descr_nb ) {
		path_descr*  curD=descr_data+curP;
		int          nType=curD->flags&descr_type_mask;
		bool         nWeight=curD->flags&descr_weighted;
		float        nextX,nextY,nextW;
		if ( nType == descr_forced ) {
			if ( weighted ) AddForcedPoint(curX,curY,curW,curP,1.0); else AddForcedPoint(curX,curY,curP,1.0);
			curP++;
		} else if ( nType == descr_moveto ) {
			nextX=curD->d.m.x;
			nextY=curD->d.m.y;
			if ( nWeight ) nextW=curD->d.m.w; else nextW=1;
			if ( weighted ) lastMoveTo=AddPoint(nextX,nextY,nextW,curP,0.0,true); else lastMoveTo=AddPoint(nextX,nextY,curP,0.0,true);
			// et on avance
			curP++;
		} else if ( nType == descr_close ) {
			if ( weighted ) {
				nextX=((path_lineto_wb*)pts)[lastMoveTo].x;
				nextY=((path_lineto_wb*)pts)[lastMoveTo].y;
				nextW=((path_lineto_wb*)pts)[lastMoveTo].w;
				AddPoint(nextX,nextY,nextW,curP,1.0,false);
			} else {
				nextX=((path_lineto_b*)pts)[lastMoveTo].x;
				nextY=((path_lineto_b*)pts)[lastMoveTo].y;
				AddPoint(nextX,nextY,curP,1.0,false);
			}
			curP++;
		} else if ( nType == descr_lineto ) {
			nextX=curD->d.l.x;
			nextY=curD->d.l.y;
			if ( nWeight ) nextW=curD->d.l.w; else nextW=1;
			if ( weighted ) AddPoint(nextX,nextY,nextW,curP,1.0,false); else AddPoint(nextX,nextY,curP,1.0,false);
			// et on avance
			curP++;
		} else if ( nType == descr_cubicto ) {
			nextX=curD->d.c.x;
			nextY=curD->d.c.y;
			if ( nWeight ) nextW=curD->d.c.w; else nextW=1;
			if ( weighted ) {
				RecCubicTo(curX,curY,curW,curD->d.c.stDx,curD->d.c.stDy,nextX,nextY,nextW,curD->d.c.enDx,curD->d.c.enDy,treshhold,8,0.0,1.0,curP);
				AddPoint(nextX,nextY,nextW,curP,1.0,false);
			} else {
				RecCubicTo(curX,curY,curD->d.c.stDx,curD->d.c.stDy,nextX,nextY,curD->d.c.enDx,curD->d.c.enDy,treshhold,8,0.0,1.0,curP);
				AddPoint(nextX,nextY,curP,1.0,false);
			}
			// et on avance
			curP++;
		} else if ( nType == descr_arcto ) {
			nextX=curD->d.a.x;
			nextY=curD->d.a.y;
			if ( nWeight ) nextW=curD->d.a.w; else nextW=1;
			if ( weighted ) {
				DoArc(curX,curY,curW,nextX,nextY,nextW,curD->d.a.rx,curD->d.a.ry,curD->d.a.angle,curD->d.a.large,curD->d.a.clockwise,treshhold,curP);
				AddPoint(nextX,nextY,nextW,curP,1.0,false);
			} else {
				DoArc(curX,curY,nextX,nextY,curD->d.a.rx,curD->d.a.ry,curD->d.a.angle,curD->d.a.large,curD->d.a.clockwise,treshhold,curP);
				AddPoint(nextX,nextY,curP,1.0,false);
			}
			// et on avance
			curP++;
		} else if ( nType == descr_bezierto ) {
			int   nbInterm=curD->d.b.nb;
			nextX=curD->d.b.x;
			nextY=curD->d.b.y;
			if ( nWeight ) nextW=curD->d.b.w; else nextW=1;
			
			curD=descr_data+(curP+1);
			path_descr* intermPoints=curD;
			
			if ( nbInterm <= 0 ) {
				/*			} else if ( nbInterm == 1 ) {
				float midX,midY,midW;
				midX=intermPoints->d.i.x;
				midY=intermPoints->d.i.y;
				if ( nWeight ) {
					midW=intermPoints->d.i.w;
				} else {
					midW=1;
				}
				if ( weighted ) {
					RecBezierTo(midX,midY,midW,curX,curY,curW,nextX,nextY,nextW,treshhold,8,0.0,1.0,curP);
				} else {
					RecBezierTo(midX,midY,curX,curY,nextX,nextY,treshhold,8,0.0,1.0,curP);
				}*/
				} else if ( nbInterm >= 1 ) {
					float   bx=curX,by=curY,bw=curW;
					float   cx=curX,cy=curY,cw=curW;
					float   dx=curX,dy=curY,dw=curW;
					
					dx=intermPoints->d.i.x;
					dy=intermPoints->d.i.y;
					if ( nWeight ) {
						dw=intermPoints->d.i.w;
					} else {
						dw=1;
					}
					intermPoints++;
					
					cx=2*bx-dx;
					cy=2*by-dy;
					cw=2*bw-dw;
					
					for (int k=0;k<nbInterm-1;k++) {
						bx=cx;by=cy;bw=cw;
						cx=dx;cy=dy;cw=dw;
						
						dx=intermPoints->d.i.x;
						dy=intermPoints->d.i.y;
						if ( nWeight ) {
							dw=intermPoints->d.i.w;
						} else {
							dw=1;
						}
						intermPoints++;
						
						float  stx=(bx+cx)/2;
						float  sty=(by+cy)/2;
						float  stw=(bw+cw)/2;
						if ( k > 0 ) {
							if ( weighted ) AddPoint(stx,sty,stw,curP-1+k,1.0,false); else AddPoint(stx,sty,curP-1+k,1.0,false);
						}
						
						if ( weighted ) {
							RecBezierTo(cx,cy,cw,stx,sty,stw,(cx+dx)/2,(cy+dy)/2,(cw+dw)/2,treshhold,8,0.0,1.0,curP+k);
						} else {
							RecBezierTo(cx,cy,stx,sty,(cx+dx)/2,(cy+dy)/2,treshhold,8,0.0,1.0,curP+k);
						}
					}
					{
						bx=cx;by=cy;bw=cw;
						cx=dx;cy=dy;cw=dw;
						
						dx=nextX;
						dy=nextY;
						if ( nWeight ) {
							dw=nextW;
						} else {
							dw=1;
						}
						dx=2*dx-cx;
						dy=2*dy-cy;
						dw=2*dw-cw;
						
						float  stx=(bx+cx)/2;
						float  sty=(by+cy)/2;
						float  stw=(bw+cw)/2;
						
						if ( nbInterm > 1 ) {
							if ( weighted ) AddPoint(stx,sty,stw,curP+nbInterm-2,1.0,false); else AddPoint(stx,sty,curP+nbInterm-2,1.0,false);
						}
						
						if ( weighted ) {
							RecBezierTo(cx,cy,cw,stx,sty,stw,(cx+dx)/2,(cy+dy)/2,(cw+dw)/2,treshhold,8,0.0,1.0,curP+nbInterm-1);
						} else {
							RecBezierTo(cx,cy,stx,sty,(cx+dx)/2,(cy+dy)/2,treshhold,8,0.0,1.0,curP+nbInterm-1);
						}
					}
					
				}
			
			
			if ( weighted ) AddPoint(nextX,nextY,nextW,curP-1+nbInterm,1.0,false); else AddPoint(nextX,nextY,curP-1+nbInterm,1.0,false);
			
			// et on avance
			curP+=1+nbInterm;
		}
		curX=nextX;
		curY=nextY;
		curW=nextW;
	}
}
void            Path::ConvertForOffset(float treshhold,Path* orig,float off_dec)
{
	if ( descr_flags&descr_adding_bezier ) CancelBezier();
	if ( descr_flags&descr_doing_subpath ) CloseSubpath(0);
	
	SetBackData(true);
	ResetPoints(descr_nb);
	if ( descr_nb <= 0 ) return;
	float    curX,curY,curW;
	int      curP=1;
	int      lastMoveTo=0;
	
	// le moveto
	curX=(descr_data)->d.m.x;
	curY=(descr_data)->d.m.y;
	if ( (descr_data)->flags&descr_weighted ) {
		curW=(descr_data)->d.m.w;
	} else {
		curW=1;
	}
	lastMoveTo=AddPoint(curX,curY,0,0.0,true);
	
	offset_orig     off_data;
	off_data.orig=orig;
	off_data.off_dec=off_dec;
	
		// et le reste, 1 par 1
	while ( curP < descr_nb ) {
		path_descr*  curD=descr_data+curP;
		int          nType=curD->flags&descr_type_mask;
		bool         nWeight=curD->flags&descr_weighted;
		float        nextX,nextY,nextW;
		if ( nType == descr_forced ) {
			AddForcedPoint(curX,curY,curP,1.0);
			curP++;
		} else if ( nType == descr_moveto ) {
			nextX=curD->d.m.x;
			nextY=curD->d.m.y;
			if ( nWeight ) nextW=curD->d.m.w; else nextW=1;
			lastMoveTo=AddPoint(nextX,nextY,curP,0.0,true);
			// et on avance
			curP++;
		} else if ( nType == descr_close ) {
			nextX=((path_lineto_b*)pts)[lastMoveTo].x;
			nextY=((path_lineto_b*)pts)[lastMoveTo].y;
			AddPoint(nextX,nextY,curP,1.0,false);
			curP++;
		} else if ( nType == descr_lineto ) {
			nextX=curD->d.l.x;
			nextY=curD->d.l.y;
			if ( nWeight ) nextW=curD->d.l.w; else nextW=1;
			AddPoint(nextX,nextY,curP,1.0,false);
			// et on avance
			curP++;
		} else if ( nType == descr_cubicto ) {
			nextX=curD->d.c.x;
			nextY=curD->d.c.y;
			if ( nWeight ) nextW=curD->d.c.w; else nextW=1;
			off_data.piece=curD->associated;
			off_data.tSt=curD->tSt;
			off_data.tEn=curD->tEn;
			if ( curD->associated >= 0 ) {
				RecCubicTo(curX,curY,curD->d.c.stDx,curD->d.c.stDy,nextX,nextY,curD->d.c.enDx,curD->d.c.enDy,treshhold,8,0.0,1.0,curP,off_data);
			} else {
				RecCubicTo(curX,curY,curD->d.c.stDx,curD->d.c.stDy,nextX,nextY,curD->d.c.enDx,curD->d.c.enDy,treshhold,8,0.0,1.0,curP);
			}
			AddPoint(nextX,nextY,curP,1.0,false);
			// et on avance
			curP++;
		} else if ( nType == descr_arcto ) {
			nextX=curD->d.a.x;
			nextY=curD->d.a.y;
			if ( nWeight ) nextW=curD->d.a.w; else nextW=1;
			off_data.piece=curD->associated;
			off_data.tSt=curD->tSt;
			off_data.tEn=curD->tEn;
			if ( curD->associated >= 0 ) {
				DoArc(curX,curY,nextX,nextY,curD->d.a.rx,curD->d.a.ry,curD->d.a.angle,curD->d.a.large,curD->d.a.clockwise,treshhold,curP,off_data);
			} else {
				DoArc(curX,curY,nextX,nextY,curD->d.a.rx,curD->d.a.ry,curD->d.a.angle,curD->d.a.large,curD->d.a.clockwise,treshhold,curP);
			}
			AddPoint(nextX,nextY,curP,1.0,false);
			// et on avance
			curP++;
		} else if ( nType == descr_bezierto ) {
			// on ne devrait jamais avoir de bezier quadratiques dans les offsets
			// mais bon, par precaution...
			int   nbInterm=curD->d.b.nb;
			nextX=curD->d.b.x;
			nextY=curD->d.b.y;
			if ( nWeight ) nextW=curD->d.b.w; else nextW=1;
			
			curD=descr_data+(curP+1);
			path_descr* intermPoints=curD;
			
			if ( nbInterm <= 0 ) {
				/*			} else if ( nbInterm == 1 ) {
				float midX,midY,midW;
				midX=intermPoints->d.i.x;
				midY=intermPoints->d.i.y;
				if ( nWeight ) {
					midW=intermPoints->d.i.w;
				} else {
					midW=1;
				}
				if ( weighted ) {
					RecBezierTo(midX,midY,midW,curX,curY,curW,nextX,nextY,nextW,treshhold,8,0.0,1.0,curP);
				} else {
					RecBezierTo(midX,midY,curX,curY,nextX,nextY,treshhold,8,0.0,1.0,curP);
				}*/
			} else if ( nbInterm >= 1 ) {
					float   bx=curX,by=curY,bw=curW;
					float   cx=curX,cy=curY,cw=curW;
					float   dx=curX,dy=curY,dw=curW;
					
					dx=intermPoints->d.i.x;
					dy=intermPoints->d.i.y;
					if ( nWeight ) {
						dw=intermPoints->d.i.w;
					} else {
						dw=1;
					}
					intermPoints++;
					
					cx=2*bx-dx;
					cy=2*by-dy;
					cw=2*bw-dw;
					
					for (int k=0;k<nbInterm-1;k++) {
						bx=cx;by=cy;bw=cw;
						cx=dx;cy=dy;cw=dw;
						
						dx=intermPoints->d.i.x;
						dy=intermPoints->d.i.y;
						if ( nWeight ) {
							dw=intermPoints->d.i.w;
						} else {
							dw=1;
						}
						intermPoints++;
						
						float  stx=(bx+cx)/2;
						float  sty=(by+cy)/2;
//						float  stw=(bw+cw)/2;
						if ( k > 0 ) {
							AddPoint(stx,sty,curP-1+k,1.0,false);
						}
						
						off_data.piece=intermPoints->associated;
						off_data.tSt=intermPoints->tSt;
						off_data.tEn=intermPoints->tEn;
						if ( intermPoints->associated >= 0 ) {
							RecBezierTo(cx,cy,stx,sty,(cx+dx)/2,(cy+dy)/2,treshhold,8,0.0,1.0,curP+k,off_data);
						} else {
							RecBezierTo(cx,cy,stx,sty,(cx+dx)/2,(cy+dy)/2,treshhold,8,0.0,1.0,curP+k);
						}
					}
					{
						bx=cx;by=cy;bw=cw;
						cx=dx;cy=dy;cw=dw;
						
						dx=nextX;
						dy=nextY;
						if ( nWeight ) {
							dw=nextW;
						} else {
							dw=1;
						}
						dx=2*dx-cx;
						dy=2*dy-cy;
						dw=2*dw-cw;
						
						float  stx=(bx+cx)/2;
						float  sty=(by+cy)/2;
//						float  stw=(bw+cw)/2;
						
						if ( nbInterm > 1 ) {
							AddPoint(stx,sty,curP+nbInterm-2,1.0,false);
						}
						
						off_data.piece=curD->associated;
						off_data.tSt=curD->tSt;
						off_data.tEn=curD->tEn;
						if ( curD->associated >= 0 ) {
							RecBezierTo(cx,cy,stx,sty,(cx+dx)/2,(cy+dy)/2,treshhold,8,0.0,1.0,curP+nbInterm-1,off_data);
						} else {
							RecBezierTo(cx,cy,stx,sty,(cx+dx)/2,(cy+dy)/2,treshhold,8,0.0,1.0,curP+nbInterm-1);
						}
					}
					
				}
			
			
			AddPoint(nextX,nextY,curP-1+nbInterm,1.0,false);
			
			// et on avance
			curP+=1+nbInterm;
		}
		curX=nextX;
		curY=nextY;
		curW=nextW;
	}
}
void            Path::Convert(float treshhold)
{
	if ( descr_flags&descr_adding_bezier ) CancelBezier();
	if ( descr_flags&descr_doing_subpath ) CloseSubpath(0);
	
	SetBackData(false);
	ResetPoints(descr_nb);
	if ( descr_nb <= 0 ) return;
	float    curX,curY,curW;
	int      curP=1;
	int      lastMoveTo=0;
	
	// le moveto
	curX=(descr_data)->d.m.x;
	curY=(descr_data)->d.m.y;
	if ( (descr_data)->flags&descr_weighted ) {
		curW=(descr_data)->d.m.w;
	} else {
		curW=1;
	}
	if ( weighted ) lastMoveTo=AddPoint(curX,curY,curW,true); else lastMoveTo=AddPoint(curX,curY,true);
	(descr_data)->associated=lastMoveTo;
	
		// et le reste, 1 par 1
	while ( curP < descr_nb ) {
		path_descr*  curD=descr_data+curP;
		int          nType=curD->flags&descr_type_mask;
		bool         nWeight=curD->flags&descr_weighted;
		float        nextX,nextY,nextW;
		if ( nType == descr_forced ) {
			if ( weighted ) (curD)->associated=AddForcedPoint(curX,curY,curW); else (curD)->associated=AddForcedPoint(curX,curY);
			curP++;
		} else if ( nType == descr_moveto ) {
			nextX=curD->d.m.x;
			nextY=curD->d.m.y;
			if ( nWeight ) nextW=curD->d.m.w; else nextW=1;
			if ( weighted ) lastMoveTo=AddPoint(nextX,nextY,nextW,true); else lastMoveTo=AddPoint(nextX,nextY,true);
			curD->associated=lastMoveTo;
			
			// et on avance
			curP++;
		} else if ( nType == descr_close ) {
			if ( weighted ) {
				nextX=((path_lineto_w*)pts)[lastMoveTo].x;
				nextY=((path_lineto_w*)pts)[lastMoveTo].y;
				nextW=((path_lineto_w*)pts)[lastMoveTo].w;
				curD->associated=AddPoint(nextX,nextY,nextW,false);
				if ( curD->associated < 0 ) {
					if ( curP == 0 ) {
						curD->associated=0;
					} else {
						curD->associated=(curD-1)->associated;
					}
				}
			} else {
				nextX=((path_lineto*)pts)[lastMoveTo].x;
				nextY=((path_lineto*)pts)[lastMoveTo].y;
				curD->associated=AddPoint(nextX,nextY,false);
				if ( curD->associated < 0 ) {
					if ( curP == 0 ) {
						curD->associated=0;
					} else {
						curD->associated=(curD-1)->associated;
					}
				}
			}
			curP++;
		} else if ( nType == descr_lineto ) {
			nextX=curD->d.l.x;
			nextY=curD->d.l.y;
			if ( nWeight ) nextW=curD->d.l.w; else nextW=1;
			if ( weighted ) curD->associated=AddPoint(nextX,nextY,nextW,false); else curD->associated=AddPoint(nextX,nextY,false);
			if ( curD->associated < 0 ) {
				if ( curP == 0 ) {
					curD->associated=0;
				} else {
					curD->associated=(curD-1)->associated;
				}
			}
			// et on avance
			curP++;
		} else if ( nType == descr_cubicto ) {
			nextX=curD->d.c.x;
			nextY=curD->d.c.y;
			if ( nWeight ) nextW=curD->d.c.w; else nextW=1;
			if ( weighted ) {
				RecCubicTo(curX,curY,curW,curD->d.c.stDx,curD->d.c.stDy,nextX,nextY,nextW,curD->d.c.enDx,curD->d.c.enDy,treshhold,8);
				curD->associated=AddPoint(nextX,nextY,nextW,false);
				if ( curD->associated < 0 ) {
					if ( curP == 0 ) {
						curD->associated=0;
					} else {
						curD->associated=(curD-1)->associated;
					}
				}
			} else {
				RecCubicTo(curX,curY,curD->d.c.stDx,curD->d.c.stDy,nextX,nextY,curD->d.c.enDx,curD->d.c.enDy,treshhold,8);
				curD->associated=AddPoint(nextX,nextY,false);
				if ( curD->associated < 0 ) {
					if ( curP == 0 ) {
						curD->associated=0;
					} else {
						curD->associated=(curD-1)->associated;
					}
				}
			}
			// et on avance
			curP++;
		} else if ( nType == descr_arcto ) {
			nextX=curD->d.a.x;
			nextY=curD->d.a.y;
			if ( nWeight ) nextW=curD->d.a.w; else nextW=1;
			if ( weighted ) {
				DoArc(curX,curY,curW,nextX,nextY,nextW,curD->d.a.rx,curD->d.a.ry,curD->d.a.angle,curD->d.a.large,curD->d.a.clockwise,treshhold);
				curD->associated=AddPoint(nextX,nextY,nextW,false);
				if ( curD->associated < 0 ) {
					if ( curP == 0 ) {
						curD->associated=0;
					} else {
						curD->associated=(curD-1)->associated;
					}
				}
			} else {
				DoArc(curX,curY,nextX,nextY,curD->d.a.rx,curD->d.a.ry,curD->d.a.angle,curD->d.a.large,curD->d.a.clockwise,treshhold);
				curD->associated=AddPoint(nextX,nextY,false);
				if ( curD->associated < 0 ) {
					if ( curP == 0 ) {
						curD->associated=0;
					} else {
						curD->associated=(curD-1)->associated;
					}
				}
			}
			// et on avance
			curP++;
		} else if ( nType == descr_bezierto ) {
			int   nbInterm=curD->d.b.nb;
			nextX=curD->d.b.x;
			nextY=curD->d.b.y;
			if ( nWeight ) nextW=curD->d.b.w; else nextW=1;
			path_descr* curBD=curD;
			
			curP++;
			curD=descr_data+curP;
			path_descr* intermPoints=curD;
			
			if ( nbInterm <= 0 ) {
			} else if ( nbInterm == 1 ) {
				float midX,midY,midW;
				midX=intermPoints->d.i.x;
				midY=intermPoints->d.i.y;
				if ( nWeight ) {
					midW=intermPoints->d.i.w;
				} else {
					midW=1;
				}
				if ( weighted ) {
					RecBezierTo(midX,midY,midW,curX,curY,curW,nextX,nextY,nextW,treshhold,8);
				} else {
					RecBezierTo(midX,midY,curX,curY,nextX,nextY,treshhold,8);
				}
			} else if ( nbInterm > 1 ) {
				float   bx=curX,by=curY,bw=curW;
				float   cx=curX,cy=curY,cw=curW;
				float   dx=curX,dy=curY,dw=curW;
								
				dx=intermPoints->d.i.x;
				dy=intermPoints->d.i.y;
				if ( nWeight ) {
					dw=intermPoints->d.i.w;
				} else {
					dw=1;
				}
				intermPoints++;
				
				cx=2*bx-dx;
				cy=2*by-dy;
				cw=2*bw-dw;
				
				for (int k=0;k<nbInterm-1;k++) {
					bx=cx;by=cy;bw=cw;
					cx=dx;cy=dy;cw=dw;
					
					dx=intermPoints->d.i.x;
					dy=intermPoints->d.i.y;
					if ( nWeight ) {
						dw=intermPoints->d.i.w;
					} else {
						dw=1;
					}
					intermPoints++;
					
					float  stx=(bx+cx)/2;
					float  sty=(by+cy)/2;
					float  stw=(bw+cw)/2;
					if ( k > 0 ) {
						if ( weighted ) (intermPoints-2)->associated=AddPoint(stx,sty,stw,false); else (intermPoints-2)->associated=AddPoint(stx,sty,false);
						if ( (intermPoints-2)->associated < 0 ) {
							if ( curP == 0 ) {
								(intermPoints-2)->associated=0;
							} else {
								(intermPoints-2)->associated=(intermPoints-3)->associated;
							}
						}
					}
					
					if ( weighted ) {
						RecBezierTo(cx,cy,cw,stx,sty,stw,(cx+dx)/2,(cy+dy)/2,(cw+dw)/2,treshhold,8);
					} else {
						RecBezierTo(cx,cy,stx,sty,(cx+dx)/2,(cy+dy)/2,treshhold,8);
					}
				}
				{
					bx=cx;by=cy;bw=cw;
					cx=dx;cy=dy;cw=dw;
					
					dx=nextX;
					dy=nextY;
					if ( nWeight ) {
						dw=nextW;
					} else {
						dw=1;
					}
					dx=2*dx-cx;
					dy=2*dy-cy;
					dw=2*dw-cw;
					
					float  stx=(bx+cx)/2;
					float  sty=(by+cy)/2;
					float  stw=(bw+cw)/2;
					
					if ( weighted ) (intermPoints-1)->associated=AddPoint(stx,sty,stw,false); else (intermPoints-1)->associated=AddPoint(stx,sty,false);
					if ( (intermPoints-1)->associated < 0 ) {
						if ( curP == 0 ) {
							(intermPoints-1)->associated=0;
						} else {
							(intermPoints-1)->associated=(intermPoints-2)->associated;
						}
					}
					
					if ( weighted ) {
						RecBezierTo(cx,cy,cw,stx,sty,stw,(cx+dx)/2,(cy+dy)/2,(cw+dw)/2,treshhold,8);
					} else {
						RecBezierTo(cx,cy,stx,sty,(cx+dx)/2,(cy+dy)/2,treshhold,8);
					}
				}
			}
			if ( weighted ) curBD->associated=AddPoint(nextX,nextY,nextW,false); else curBD->associated=AddPoint(nextX,nextY,false);
			if ( (curBD)->associated < 0 ) {
				if ( curP == 0 ) {
					(curBD)->associated=0;
				} else {
					(curBD)->associated=(curBD-1)->associated;
				}
			}
			
			// et on avance
			curP+=nbInterm;
		}
		curX=nextX;
		curY=nextY;
		curW=nextW;
	}
}
void            Path::ConvertEvenLines(float treshhold)
{
	if ( descr_flags&descr_adding_bezier ) CancelBezier();
	if ( descr_flags&descr_doing_subpath ) CloseSubpath(0);
	
	SetBackData(false);
	ResetPoints(descr_nb);
	if ( descr_nb <= 0 ) return;
	float    curX,curY,curW;
	int      curP=1;
	int      lastMoveTo=0;
	
	// le moveto
	curX=(descr_data)->d.m.x;
	curY=(descr_data)->d.m.y;
	if ( (descr_data)->flags&descr_weighted ) {
		curW=(descr_data)->d.m.w;
	} else {
		curW=1;
	}
	if ( weighted ) lastMoveTo=AddPoint(curX,curY,curW,true); else lastMoveTo=AddPoint(curX,curY,true);
	(descr_data)->associated=lastMoveTo;
	
		// et le reste, 1 par 1
	while ( curP < descr_nb ) {
		path_descr*  curD=descr_data+curP;
		int          nType=curD->flags&descr_type_mask;
		bool         nWeight=curD->flags&descr_weighted;
		float        nextX,nextY,nextW;
		if ( nType == descr_forced ) {
			if ( weighted ) (curD)->associated=AddForcedPoint(curX,curY,curW); else (curD)->associated=AddForcedPoint(curX,curY);
			curP++;
		} else if ( nType == descr_moveto ) {
			nextX=curD->d.m.x;
			nextY=curD->d.m.y;
			if ( nWeight ) nextW=curD->d.m.w; else nextW=1;
			if ( weighted ) lastMoveTo=AddPoint(nextX,nextY,nextW,true); else lastMoveTo=AddPoint(nextX,nextY,true);
			(curD)->associated=lastMoveTo;
			// et on avance
			curP++;
		} else if ( nType == descr_close ) {
			if ( weighted ) {
				nextX=((path_lineto_w*)pts)[lastMoveTo].x;
				nextY=((path_lineto_w*)pts)[lastMoveTo].y;
				nextW=((path_lineto_w*)pts)[lastMoveTo].w;
				{
					float segL=sqrt((nextX-curX)*(nextX-curX)+(nextY-curY)*(nextY-curY));
					if ( segL > 4*treshhold ) {
						for (float i=4*treshhold;i<segL;i+=4*treshhold) {
							AddPoint(((segL-i)*curX+i*nextX)/segL,((segL-i)*curY+i*nextY)/segL,((segL-i)*curW+i*nextW)/segL);
						}
					}
				}
				curD->associated=AddPoint(nextX,nextY,nextW,false);
				if ( curD->associated < 0 ) {
					if ( curP == 0 ) {
						curD->associated=0;
					} else {
						curD->associated=(curD-1)->associated;
					}
				}
			} else {
				nextX=((path_lineto*)pts)[lastMoveTo].x;
				nextY=((path_lineto*)pts)[lastMoveTo].y;
				{
					float segL=sqrt((nextX-curX)*(nextX-curX)+(nextY-curY)*(nextY-curY));
					if ( segL > 4*treshhold ) {
						for (float i=4*treshhold;i<segL;i+=4*treshhold) {
							AddPoint(((segL-i)*curX+i*nextX)/segL,((segL-i)*curY+i*nextY)/segL);
						}
					}
				}
				curD->associated=AddPoint(nextX,nextY,false);
				if ( curD->associated < 0 ) {
					if ( curP == 0 ) {
						curD->associated=0;
					} else {
						curD->associated=(curD-1)->associated;
					}
				}
			}
			curP++;
		} else if ( nType == descr_lineto ) {
			nextX=curD->d.l.x;
			nextY=curD->d.l.y;
			if ( nWeight ) nextW=curD->d.l.w; else nextW=1;
			if ( weighted ) {
				float segL=sqrt((nextX-curX)*(nextX-curX)+(nextY-curY)*(nextY-curY));
				if ( segL > 4*treshhold ) {
					for (float i=4*treshhold;i<segL;i+=4*treshhold) {
						AddPoint(((segL-i)*curX+i*nextX)/segL,((segL-i)*curY+i*nextY)/segL,((segL-i)*curW+i*nextW)/segL);
					}
				}
				curD->associated=AddPoint(nextX,nextY,nextW,false);
				if ( curD->associated < 0 ) {
					if ( curP == 0 ) {
						curD->associated=0;
					} else {
						curD->associated=(curD-1)->associated;
					}
				}
			} else {
				float segL=sqrt((nextX-curX)*(nextX-curX)+(nextY-curY)*(nextY-curY));
				if ( segL > 4*treshhold ) {
					for (float i=4*treshhold;i<segL;i+=4*treshhold) {
						AddPoint(((segL-i)*curX+i*nextX)/segL,((segL-i)*curY+i*nextY)/segL);
					}
				}
				curD->associated=AddPoint(nextX,nextY,false);
				if ( curD->associated < 0 ) {
					if ( curP == 0 ) {
						curD->associated=0;
					} else {
						curD->associated=(curD-1)->associated;
					}
				}
			}
			// et on avance
			curP++;
		} else if ( nType == descr_cubicto ) {
			nextX=curD->d.c.x;
			nextY=curD->d.c.y;
			if ( nWeight ) nextW=curD->d.c.w; else nextW=1;
			if ( weighted ) {
				RecCubicTo(curX,curY,curW,curD->d.c.stDx,curD->d.c.stDy,nextX,nextY,nextW,curD->d.c.enDx,curD->d.c.enDy,treshhold,8,4*treshhold);
				curD->associated=AddPoint(nextX,nextY,nextW,false);
				if ( curD->associated < 0 ) {
					if ( curP == 0 ) {
						curD->associated=0;
					} else {
						curD->associated=(curD-1)->associated;
					}
				}
			} else {
				RecCubicTo(curX,curY,curD->d.c.stDx,curD->d.c.stDy,nextX,nextY,curD->d.c.enDx,curD->d.c.enDy,treshhold,8,4*treshhold);
				curD->associated=AddPoint(nextX,nextY,false);
				if ( curD->associated < 0 ) {
					if ( curP == 0 ) {
						curD->associated=0;
					} else {
						curD->associated=(curD-1)->associated;
					}
				}
			}
			// et on avance
			curP++;
		} else if ( nType == descr_arcto ) {
			nextX=curD->d.a.x;
			nextY=curD->d.a.y;
			if ( nWeight ) nextW=curD->d.a.w; else nextW=1;
			if ( weighted ) {
				DoArc(curX,curY,curW,nextX,nextY,nextW,curD->d.a.rx,curD->d.a.ry,curD->d.a.angle,curD->d.a.large,curD->d.a.clockwise,treshhold);
				curD->associated=AddPoint(nextX,nextY,nextW,false);
				if ( curD->associated < 0 ) {
					if ( curP == 0 ) {
						curD->associated=0;
					} else {
						curD->associated=(curD-1)->associated;
					}
				}
			} else {
				DoArc(curX,curY,nextX,nextY,curD->d.a.rx,curD->d.a.ry,curD->d.a.angle,curD->d.a.large,curD->d.a.clockwise,treshhold);
				curD->associated=AddPoint(nextX,nextY,false);
				if ( curD->associated < 0 ) {
					if ( curP == 0 ) {
						curD->associated=0;
					} else {
						curD->associated=(curD-1)->associated;
					}
				}
			}
			// et on avance
			curP++;
		} else if ( nType == descr_bezierto ) {
			int   nbInterm=curD->d.b.nb;
			nextX=curD->d.b.x;
			nextY=curD->d.b.y;
			if ( nWeight ) nextW=curD->d.b.w; else nextW=1;
			path_descr*  curBD=curD;
			
			curP++;
			curD=descr_data+curP;
			path_descr* intermPoints=curD;
			
			if ( nbInterm <= 0 ) {
			} else if ( nbInterm == 1 ) {
				float midX,midY,midW;
				midX=intermPoints->d.i.x;
				midY=intermPoints->d.i.y;
				if ( nWeight ) {
					midW=intermPoints->d.i.w;
				} else {
					midW=1;
				}
				if ( weighted ) {
					RecBezierTo(midX,midY,midW,curX,curY,curW,nextX,nextY,nextW,treshhold,8,4*treshhold);
				} else {
					RecBezierTo(midX,midY,curX,curY,nextX,nextY,treshhold,8,4*treshhold);
				}
			} else if ( nbInterm > 1 ) {
				float   bx=curX,by=curY,bw=curW;
				float   cx=curX,cy=curY,cw=curW;
				float   dx=curX,dy=curY,dw=curW;
								
				dx=intermPoints->d.i.x;
				dy=intermPoints->d.i.y;
				if ( nWeight ) {
					dw=intermPoints->d.i.w;
				} else {
					dw=1;
				}
				intermPoints++;
				
				cx=2*bx-dx;
				cy=2*by-dy;
				cw=2*bw-dw;
				
				for (int k=0;k<nbInterm-1;k++) {
					bx=cx;by=cy;bw=cw;
					cx=dx;cy=dy;cw=dw;
					
					dx=intermPoints->d.i.x;
					dy=intermPoints->d.i.y;
					if ( nWeight ) {
						dw=intermPoints->d.i.w;
					} else {
						dw=1;
					}
					intermPoints++;
					
					float  stx=(bx+cx)/2;
					float  sty=(by+cy)/2;
					float  stw=(bw+cw)/2;
					if ( k > 0 ) {
						if ( weighted ) (intermPoints-2)->associated=AddPoint(stx,sty,stw,false); else (intermPoints-2)->associated=AddPoint(stx,sty,false);
						if ( (intermPoints-2)->associated < 0 ) {
							if ( curP == 0 ) {
								(intermPoints-2)->associated=0;
							} else {
								(intermPoints-2)->associated=(intermPoints-3)->associated;
							}
						}
					}
					
					if ( weighted ) {
						RecBezierTo(cx,cy,cw,stx,sty,stw,(cx+dx)/2,(cy+dy)/2,(cw+dw)/2,treshhold,8,4*treshhold);
					} else {
						RecBezierTo(cx,cy,stx,sty,(cx+dx)/2,(cy+dy)/2,treshhold,8,4*treshhold);
					}
				}
				{
					bx=cx;by=cy;bw=cw;
					cx=dx;cy=dy;cw=dw;
					
					dx=nextX;
					dy=nextY;
					if ( nWeight ) {
						dw=nextW;
					} else {
						dw=1;
					}
					dx=2*dx-cx;
					dy=2*dy-cy;
					dw=2*dw-cw;
					
					float  stx=(bx+cx)/2;
					float  sty=(by+cy)/2;
					float  stw=(bw+cw)/2;
					
					if ( weighted ) (intermPoints-1)->associated=AddPoint(stx,sty,stw,false); else (intermPoints-1)->associated=AddPoint(stx,sty,false);
					if ( (intermPoints-1)->associated < 0 ) {
						if ( curP == 0 ) {
							(intermPoints-1)->associated=0;
						} else {
							(intermPoints-1)->associated=(intermPoints-2)->associated;
						}
					}
					
					if ( weighted ) {
						RecBezierTo(cx,cy,cw,stx,sty,stw,(cx+dx)/2,(cy+dy)/2,(cw+dw)/2,treshhold,8,4*treshhold);
					} else {
						RecBezierTo(cx,cy,stx,sty,(cx+dx)/2,(cy+dy)/2,treshhold,8,4*treshhold);
					}
				}
			}
			if ( weighted ) curBD->associated=AddPoint(nextX,nextY,nextW,false); else curBD->associated=AddPoint(nextX,nextY,false);
			if ( (curBD)->associated < 0 ) {
				if ( curP == 0 ) {
					(curBD)->associated=0;
				} else {
					(curBD)->associated=(curBD-1)->associated;
				}
			}
						
			// et on avance
			curP+=nbInterm;
		}
		if ( fabsf(curX-nextX) > 0.00001 || fabsf(curY-nextY) > 0.00001 ) {
			curX=nextX;
			curY=nextY;
		}
		curW=nextW;
	}
}
void						Path::PrevPoint(int i,float &x,float &y)
{
	if ( i < 0 ) return;
	int t=descr_data[i].flags&descr_type_mask;
	if ( t == descr_forced ) {
		PrevPoint(i-1,x,y);
	} else if ( t == descr_moveto ) {
		x=descr_data[i].d.m.x;
		y=descr_data[i].d.m.y;
	} else if ( t == descr_lineto ) {
		x=descr_data[i].d.l.x;
		y=descr_data[i].d.l.y;
	} else if ( t == descr_arcto ) {
		x=descr_data[i].d.a.x;
		y=descr_data[i].d.a.y;
	} else if ( t == descr_cubicto ) {
		x=descr_data[i].d.c.x;
		y=descr_data[i].d.c.y;
	} else if ( t == descr_bezierto ) {
		x=descr_data[i].d.b.x;
		y=descr_data[i].d.b.y;
	} else if ( t == descr_interm_bezier ) {
		PrevPoint(i-1,x,y);
	} else if ( t == descr_close ) {
		PrevPoint(i-1,x,y);
	}
}
void            Path::QuadraticPoint(float t,float &ox,float &oy,float sx,float sy,float mx,float my,float ex,float ey)
{
	float ax,bx,cx;
	float ay,by,cy;
	ax=ex-2*mx+sx;
	bx=2*mx-2*sx;
	cx=sx;
	ay=ey-2*my+sy;
	by=2*my-2*sy;
	cy=sy;
	
	ox=ax*t*t+bx*t+cx;
	oy=ay*t*t+by*t+cy;
}
void            Path::CubicTangent(float t,float &ox,float &oy,float sx,float sy,float sdx,float sdy,float ex,float ey,float edx,float edy)
{
	float ax,bx,cx,dx;
	float ay,by,cy,dy;
	ax=edx-2*ex+2*sx+sdx;
	bx=3*ex-edx-2*sdx-3*sx;
	cx=sdx;
	dx=sx;
	ay=edy-2*ey+2*sy+sdy;
	by=3*ey-edy-2*sdy-3*sy;
	cy=sdy;
	dy=sy;
	
	ox=3*ax*t*t+2*bx*t+cx;
	oy=3*ay*t*t+2*by*t+cy;
}
void            Path::ArcAngles(float sx,float sy,float ex,float ey,float rx,float ry,float angle,bool large,bool wise,float &sang,float &eang)
{
	float   sex=ex-sx,sey=ey-sy;
	float   ca=cos(angle),sa=sin(angle);
	float   csex=ca*sex+sa*sey,csey=-sa*sex+ca*sey;
	csex/=rx;csey/=ry;
	float   l=csex*csex+csey*csey;
	float   d=1-l/4;
	if ( d < 0 ) d=0;
	d=sqrt(d);
	float   csdx=csey,csdy=-csex;
	l=sqrt(l);
	csdx/=l;csdy/=l;
	csdx*=d;csdy*=d;
	
	float   rax=-csdx-csex/2,ray=-csdy-csey/2;
	if ( rax < -1 ) {
		sang=M_PI;
	} else if ( rax > 1 ) {
		sang=0;
	} else {
		sang=acos(rax);
		if ( ray < 0 ) sang=2*M_PI-sang;
	}
	rax=-csdx+csex/2;ray=-csdy+csey/2;
	if ( rax < -1 ) {
		eang=M_PI;
	} else if ( rax > 1 ) {
		eang=0;
	} else {
		eang=acos(rax);
		if ( ray < 0 ) eang=2*M_PI-eang;
	}
	
	csdx*=rx;csdy*=ry;
	float   drx=ca*csdx-sa*csdy,dry=sa*csdx+ca*csdy;
	
	if ( wise ) {
		if ( large == true ) {
			drx=-drx;dry=-dry;
			float  swap=eang;eang=sang;sang=swap;
			eang+=M_PI;sang+=M_PI;
			if ( eang >= 2*M_PI ) eang-=2*M_PI;
			if ( sang >= 2*M_PI ) sang-=2*M_PI;
		}
	} else {
		if ( large == false ) {
			drx=-drx;dry=-dry;
			float  swap=eang;eang=sang;sang=swap;
			eang+=M_PI;sang+=M_PI;
			if ( eang >= 2*M_PI ) eang-=2*M_PI;
			if ( sang >= 2*M_PI ) sang-=2*M_PI;
		}
	}
	drx+=(sx+ex)/2;dry+=(sy+ey)/2;
}
void            Path::DoArc(float sx,float sy,float ex,float ey,float rx,float ry,float angle,bool large,bool wise,float tresh)
{
	if ( rx <= 0.0001 || ry <= 0.0001 ) return; // on ajoute toujours un lineto apres, donc c bon
	
	float   sex=ex-sx,sey=ey-sy;
	float   ca=cos(angle),sa=sin(angle);
	float   csex=ca*sex+sa*sey,csey=-sa*sex+ca*sey;
	csex/=rx;csey/=ry;
	float   l=csex*csex+csey*csey;
	if ( l >= 4 ) l=4;
	float   d=1-l/4;
	if ( d < 0 ) d=0;
	d=sqrt(d);
	float   csdx=csey,csdy=-csex;
	l=sqrt(l);
	csdx/=l;csdy/=l;
	csdx*=d;csdy*=d;

	float   sang,eang;
	float   rax=-csdx-csex/2,ray=-csdy-csey/2;
	if ( rax < -1 ) {
		sang=M_PI;
	} else if ( rax > 1 ) {
		sang=0;
	} else {
		sang=acos(rax);
		if ( ray < 0 ) sang=2*M_PI-sang;
	}
	rax=-csdx+csex/2;ray=-csdy+csey/2;
	if ( rax < -1 ) {
		eang=M_PI;
	} else if ( rax > 1 ) {
		eang=0;
	} else {
		eang=acos(rax);
		if ( ray < 0 ) eang=2*M_PI-eang;
	}
	
	csdx*=rx;csdy*=ry;
	float   drx=ca*csdx-sa*csdy,dry=sa*csdx+ca*csdy;

	if ( wise ) {
		if ( large == true ) {
			drx=-drx;dry=-dry;
			float  swap=eang;eang=sang;sang=swap;
			eang+=M_PI;sang+=M_PI;
			if ( eang >= 2*M_PI ) eang-=2*M_PI;
			if ( sang >= 2*M_PI ) sang-=2*M_PI;
		}
	} else {
		if ( large == false ) {
			drx=-drx;dry=-dry;
			float  swap=eang;eang=sang;sang=swap;
			eang+=M_PI;sang+=M_PI;
			if ( eang >= 2*M_PI ) eang-=2*M_PI;
			if ( sang >= 2*M_PI ) sang-=2*M_PI;
		}
	}
	drx+=(sx+ex)/2;dry+=(sy+ey)/2;

	if ( wise ) {
		if ( sang < eang ) sang+=2*M_PI;
		for (float b=sang-0.1;b>eang;b-=0.1) {
			float  cb=cos(b),sb=sin(b);
			float  ux,uy;
			ux=drx+ca*rx*cb-sa*ry*sb;uy=dry+sa*rx*cb+ca*ry*sb;
			AddPoint(ux,uy);
		}
	} else {
		if ( sang > eang ) sang-=2*M_PI;
		for (float b=sang+0.1;b<eang;b+=0.1) {
			float  cb=cos(b),sb=sin(b);
			float  ux,uy;
			ux=drx+ca*rx*cb-sa*ry*sb;uy=dry+sa*rx*cb+ca*ry*sb;
			AddPoint(ux,uy);
		}
	}
}
void            Path::DoArc(float sx,float sy,float sw,float ex,float ey,float ew,float rx,float ry,float angle,bool large,bool wise,float tresh)
{
	if ( rx <= 0.0001 || ry <= 0.0001 ) return; // on ajoute toujours un lineto apres, donc c bon

	float   sex=ex-sx,sey=ey-sy;
	float   ca=cos(angle),sa=sin(angle);
	float   csex=ca*sex+sa*sey,csey=-sa*sex+ca*sey;
	csex/=rx;csey/=ry;
	float   l=csex*csex+csey*csey;
	if ( l >= 4 ) l=4;
	float   d=1-l/4;
	if ( d < 0 ) d=0;
	d=sqrt(d);
	float   csdx=csey,csdy=-csex;
	l=sqrt(l);
	csdx/=l;csdy/=l;
	csdx*=d;csdy*=d;

	float   sang,eang;
	float   rax=-csdx-csex/2,ray=-csdy-csey/2;
	if ( rax < -1 ) {
		sang=M_PI;
	} else if ( rax > 1 ) {
		sang=0;
	} else {
		sang=acos(rax);
		if ( ray < 0 ) sang=2*M_PI-sang;
	}
	rax=-csdx+csex/2;ray=-csdy+csey/2;
	if ( rax < -1 ) {
		eang=M_PI;
	} else if ( rax > 1 ) {
		eang=0;
	} else {
		eang=acos(rax);
		if ( ray < 0 ) eang=2*M_PI-eang;
	}

	csdx*=rx;csdy*=ry;
	float   drx=ca*csdx-sa*csdy,dry=sa*csdx+ca*csdy;

	if ( wise ) {
		if ( large == true ) {
			drx=-drx;dry=-dry;
			float  swap=eang;eang=sang;sang=swap;
			eang+=M_PI;sang+=M_PI;
			if ( eang >= 2*M_PI ) eang-=2*M_PI;
			if ( sang >= 2*M_PI ) sang-=2*M_PI;
		}
	} else {
		if ( large == false ) {
			drx=-drx;dry=-dry;
			float  swap=eang;eang=sang;sang=swap;
			eang+=M_PI;sang+=M_PI;
			if ( eang >= 2*M_PI ) eang-=2*M_PI;
			if ( sang >= 2*M_PI ) sang-=2*M_PI;
		}
	}
	drx+=(sx+ex)/2;dry+=(sy+ey)/2;

	if ( wise ) {
		if ( sang < eang ) sang+=2*M_PI;
		for (float b=sang-0.1;b>eang;b-=0.1) {
			float  cb=cos(b),sb=sin(b);
			float  ux,uy;
			ux=drx+ca*rx*cb-sa*ry*sb;uy=dry+sa*rx*cb+ca*ry*sb;
			float  nw=(sw*(b-eang)+ew*(sang-b))/(sang-eang);
			AddPoint(ux,uy,nw);
		}
	} else {
		if ( sang > eang ) sang-=2*M_PI;
		for (float b=sang+0.1;b<eang;b+=0.1) {
			float  cb=cos(b),sb=sin(b);
			float  ux,uy;
			ux=drx+ca*rx*cb-sa*ry*sb;uy=dry+sa*rx*cb+ca*ry*sb;
			float  nw=(sw*(eang-b)+ew*(b-sang))/(eang-sang);
			AddPoint(ux,uy,nw);
		}
	}
}
void            Path::RecCubicTo(float sx,float sy,float sdx,float sdy,float ex,float ey,float edx,float edy,float tresh,int lev,float maxL)
{
	float dC=sqrt((ex-sx)*(ex-sx)+(ey-sy)*(ey-sy));
	if ( dC < 0.01 ) {
		float sC=sdy*sdy+sdx*sdx;
		float eC=edy*edy+edx*edx;
		if ( sC < tresh && eC < tresh ) return;
	} else {
		float sC=(ex-sx)*sdy-(ey-sy)*sdx;
		float eC=(ex-sx)*edy-(ey-sy)*edx;
		if ( sC < 0 ) sC=-sC;
		if ( eC < 0 ) eC=-eC;
		sC/=dC;
		eC/=dC;
		if ( sC < tresh && eC < tresh ) {
			// presque tt droit -> attention si on nous demande de bien subdiviser les petits segments
			if ( maxL > 0 && dC > maxL ) {
				if ( lev <= 0 ) return;
				float   mx,my,mdx,mdy;
				mx=(sx+ex)/2+(sdx-edx)/8;
				my=(sy+ey)/2+(sdy-edy)/8;
				mdx=3*(ex-sx)/4-(sdx+edx)/8;
				mdy=3*(ey-sy)/4-(sdy+edy)/8;
				
				RecCubicTo(sx,sy,sdx/2,sdy/2,mx,my,mdx,mdy,tresh,lev-1,maxL);
				AddPoint(mx,my);
				RecCubicTo(mx,my,mdx,mdy,ex,ey,edx/2,edy/2,tresh,lev-1,maxL);
			}
			return;
		}
	}
	
	if ( lev <= 0 ) return;
	{
		float   mx,my,mdx,mdy;
		mx=(sx+ex)/2+(sdx-edx)/8;
		my=(sy+ey)/2+(sdy-edy)/8;
		mdx=3*(ex-sx)/4-(sdx+edx)/8;
		mdy=3*(ey-sy)/4-(sdy+edy)/8;
		
		RecCubicTo(sx,sy,sdx/2,sdy/2,mx,my,mdx,mdy,tresh,lev-1,maxL);
		AddPoint(mx,my);
		RecCubicTo(mx,my,mdx,mdy,ex,ey,edx/2,edy/2,tresh,lev-1,maxL);
	}
}
void            Path::RecCubicTo(float sx,float sy,float sw,float sdx,float sdy,float ex,float ey,float ew,float edx,float edy,float tresh,int lev,float maxL)
{
	float dC=sqrt((ex-sx)*(ex-sx)+(ey-sy)*(ey-sy));
	if ( dC < 0.01 ) {
		float sC=sdy*sdy+sdx*sdx;
		float eC=edy*edy+edx*edx;
		if ( sC < tresh && eC < tresh ) return;
	} else {
		float sC=(ex-sx)*sdy-(ey-sy)*sdx;
		float eC=(ex-sx)*edy-(ey-sy)*edx;
		if ( sC < 0 ) sC=-sC;
		if ( eC < 0 ) eC=-eC;
		sC/=dC;
		eC/=dC;
		if ( sC < tresh && eC < tresh ) {
			// presque tt droit -> attention si on nous demande de bien subdiviser les petits segments
			if ( maxL > 0 && dC > maxL ) {
				if ( lev <= 0 ) return;
				float   mx,my,mw,mdx,mdy;
				mw=(sw+ew)/2;
				mx=(sx+ex)/2+(sdx-edx)/8;
				my=(sy+ey)/2+(sdy-edy)/8;
				mdx=3*(ex-sx)/4-(sdx+edx)/8;
				mdy=3*(ey-sy)/4-(sdy+edy)/8;
				
				RecCubicTo(sx,sy,sw,sdx/2,sdy/2,mx,my,mw,mdx,mdy,tresh,lev-1,maxL);
				AddPoint(mx,my,mw);
				RecCubicTo(mx,my,mw,mdx,mdy,ex,ey,ew,edx/2,edy/2,tresh,lev-1,maxL);
			}
			return;
		}
	}
		
	if ( lev <= 0 ) return;
	float   mx,my,mw,mdx,mdy;
	mw=(sw+ew)/2;
	mx=(sx+ex)/2+(sdx-edx)/8;
	my=(sy+ey)/2+(sdy-edy)/8;
	mdx=3*(ex-sx)/4-(sdx+edx)/8;
	mdy=3*(ey-sy)/4-(sdy+edy)/8;

	RecCubicTo(sx,sy,sw,sdx/2,sdy/2,mx,my,mw,mdx,mdy,tresh,lev-1,maxL);
	AddPoint(mx,my,mw);
	RecCubicTo(mx,my,mw,mdx,mdy,ex,ey,ew,edx/2,edy/2,tresh,lev-1,maxL);
}
void            Path::RecBezierTo(float px,float py,float sx,float sy,float ex,float ey,float tresh,int lev,float maxL)
{
	if ( lev <= 0 ) return;
	float s=(sx-px)*(ey-py)-(sy-py)*(ex-px);
	if ( s < 0 ) s=-s;
	if ( s < tresh ) {
		float l=sqrt((ex-sx)*(ex-sx)+(ey-sy)*(ey-sy));
		if ( maxL > 0 && l > maxL ) {
			float   mx,my,mdx,mdy;
			mx=(sx+ex+2*px)/4;
			my=(sy+ey+2*py)/4;
			mdx=(sx+px)/2;
			mdy=(sy+py)/2;
			RecBezierTo(mdx,mdy,sx,sy,mx,my,tresh,lev-1,maxL);
			AddPoint(mx,my);
			mdx=(ex+px)/2;
			mdy=(ey+py)/2;
			RecBezierTo(mdx,mdy,mx,my,ex,ey,tresh,lev-1,maxL);	
		}
		return;
	}
	{
		float   mx,my,mdx,mdy;
		mx=(sx+ex+2*px)/4;
		my=(sy+ey+2*py)/4;
		mdx=(sx+px)/2;
		mdy=(sy+py)/2;
		RecBezierTo(mdx,mdy,sx,sy,mx,my,tresh,lev-1,maxL);
		AddPoint(mx,my);
		mdx=(ex+px)/2;
		mdy=(ey+py)/2;
		RecBezierTo(mdx,mdy,mx,my,ex,ey,tresh,lev-1,maxL);	
	}
}
void            Path::RecBezierTo(float px,float py,float pw,float sx,float sy,float sw,float ex,float ey,float ew,float tresh,int lev,float maxL)
{
	if ( lev <= 0 ) return;
	float s=(sx-px)*(ey-py)-(sy-py)*(ex-px);
	if ( s < 0 ) s=-s;
	if ( s < tresh ) {
		float l=sqrt((ex-sx)*(ex-sx)+(ey-sy)*(ey-sy));
		if ( maxL > 0 && l > maxL ) {
			float   mx,my,mw,mdx,mdy,mdw;
			mx=(sx+ex+2*px)/4;
			my=(sy+ey+2*py)/4;
			mw=(sw+ew+2*pw)/4;
			mdx=(sx+px)/2;
			mdy=(sy+py)/2;
			mdw=(sw+pw)/2;
			RecBezierTo(mdx,mdy,mdw,sx,sy,sw,mx,my,mw,tresh,lev-1,maxL);
			AddPoint(mx,my,mw);
			mdx=(ex+px)/2;
			mdy=(ey+py)/2;
			mdw=(ew+pw)/2;
			RecBezierTo(mdx,mdy,mdw,mx,my,mw,ex,ey,ew,tresh,lev-1,maxL);
		}
		return;
	}
	
	float   mx,my,mw,mdx,mdy,mdw;
	mx=(sx+ex+2*px)/4;
	my=(sy+ey+2*py)/4;
	mw=(sw+ew+2*pw)/4;
	mdx=(sx+px)/2;
	mdy=(sy+py)/2;
	mdw=(sw+pw)/2;
	RecBezierTo(mdx,mdy,mdw,sx,sy,sw,mx,my,mw,tresh,lev-1,maxL);
	AddPoint(mx,my,mw);
	mdx=(ex+px)/2;
	mdy=(ey+py)/2;
	mdw=(ew+pw)/2;
	RecBezierTo(mdx,mdy,mdw,mx,my,mw,ex,ey,ew,tresh,lev-1,maxL);
}

void            Path::DoArc(float sx,float sy,float ex,float ey,float rx,float ry,float angle,bool large,bool wise,float tresh,int piece)
{
	if ( rx <= 0.0001 || ry <= 0.0001 ) return; // on ajoute toujours un lineto apres, donc c bon
	
	float   sex=ex-sx,sey=ey-sy;
	float   ca=cos(angle),sa=sin(angle);
	float   csex=ca*sex+sa*sey,csey=-sa*sex+ca*sey;
	csex/=rx;csey/=ry;
	float   l=csex*csex+csey*csey;
	if ( l >= 4 ) l=4;
	float   d=1-l/4;
	if ( d < 0 ) d=0;
	d=sqrt(d);
	float   csdx=csey,csdy=-csex;
	l=sqrt(l);
	csdx/=l;csdy/=l;
	csdx*=d;csdy*=d;

	float   sang,eang;
	float   rax=-csdx-csex/2,ray=-csdy-csey/2;
	if ( rax < -1 ) {
		sang=M_PI;
	} else if ( rax > 1 ) {
		sang=0;
	} else {
		sang=acos(rax);
		if ( ray < 0 ) sang=2*M_PI-sang;
	}
	rax=-csdx+csex/2;ray=-csdy+csey/2;
	if ( rax < -1 ) {
		eang=M_PI;
	} else if ( rax > 1 ) {
		eang=0;
	} else {
		eang=acos(rax);
		if ( ray < 0 ) eang=2*M_PI-eang;
	}
	
	csdx*=rx;csdy*=ry;
	float   drx=ca*csdx-sa*csdy,dry=sa*csdx+ca*csdy;

	if ( wise ) {
		if ( large == true ) {
			drx=-drx;dry=-dry;
			float  swap=eang;eang=sang;sang=swap;
			eang+=M_PI;sang+=M_PI;
			if ( eang >= 2*M_PI ) eang-=2*M_PI;
			if ( sang >= 2*M_PI ) sang-=2*M_PI;
		}
	} else {
		if ( large == false ) {
			drx=-drx;dry=-dry;
			float  swap=eang;eang=sang;sang=swap;
			eang+=M_PI;sang+=M_PI;
			if ( eang >= 2*M_PI ) eang-=2*M_PI;
			if ( sang >= 2*M_PI ) sang-=2*M_PI;
		}
	}
	drx+=(sx+ex)/2;dry+=(sy+ey)/2;

	if ( wise ) {
		if ( sang < eang ) sang+=2*M_PI;
		for (float b=sang-0.1;b>eang;b-=0.1) {
			float  cb=cos(b),sb=sin(b);
			float  ux,uy;
			ux=drx+ca*rx*cb-sa*ry*sb;uy=dry+sa*rx*cb+ca*ry*sb;
			AddPoint(ux,uy,piece,(sang-b)/(sang-eang));
		}
	} else {
		if ( sang > eang ) sang-=2*M_PI;
		for (float b=sang+0.1;b<eang;b+=0.1) {
			float  cb=cos(b),sb=sin(b);
			float  ux,uy;
			ux=drx+ca*rx*cb-sa*ry*sb;uy=dry+sa*rx*cb+ca*ry*sb;
			AddPoint(ux,uy,piece,(b-sang)/(eang-sang));
		}
	}
}
void            Path::DoArc(float sx,float sy,float sw,float ex,float ey,float ew,float rx,float ry,float angle,bool large,bool wise,float tresh,int piece)
{
	if ( rx <= 0.0001 || ry <= 0.0001 ) return; // on ajoute toujours un lineto apres, donc c bon

	float   sex=ex-sx,sey=ey-sy;
	float   ca=cos(angle),sa=sin(angle);
	float   csex=ca*sex+sa*sey,csey=-sa*sex+ca*sey;
	csex/=rx;csey/=ry;
	float   l=csex*csex+csey*csey;
	if ( l >= 4 ) l=4;
	float   d=1-l/4;
	if ( d < 0 ) d=0;
	d=sqrt(d);
	float   csdx=csey,csdy=-csex;
	l=sqrt(l);
	csdx/=l;csdy/=l;
	csdx*=d;csdy*=d;

	float   sang,eang;
	float   rax=-csdx-csex/2,ray=-csdy-csey/2;
	if ( rax < -1 ) {
		sang=M_PI;
	} else if ( rax > 1 ) {
		sang=0;
	} else {
		sang=acos(rax);
		if ( ray < 0 ) sang=2*M_PI-sang;
	}
	rax=-csdx+csex/2;ray=-csdy+csey/2;
	if ( rax < -1 ) {
		eang=M_PI;
	} else if ( rax > 1 ) {
		eang=0;
	} else {
		eang=acos(rax);
		if ( ray < 0 ) eang=2*M_PI-eang;
	}

	csdx*=rx;csdy*=ry;
	float   drx=ca*csdx-sa*csdy,dry=sa*csdx+ca*csdy;

	if ( wise ) {
		if ( large == true ) {
			drx=-drx;dry=-dry;
			float  swap=eang;eang=sang;sang=swap;
			eang+=M_PI;sang+=M_PI;
			if ( eang >= 2*M_PI ) eang-=2*M_PI;
			if ( sang >= 2*M_PI ) sang-=2*M_PI;
		}
	} else {
		if ( large == false ) {
			drx=-drx;dry=-dry;
			float  swap=eang;eang=sang;sang=swap;
			eang+=M_PI;sang+=M_PI;
			if ( eang >= 2*M_PI ) eang-=2*M_PI;
			if ( sang >= 2*M_PI ) sang-=2*M_PI;
		}
	}
	drx+=(sx+ex)/2;dry+=(sy+ey)/2;

	if ( wise ) {
		if ( sang < eang ) sang+=2*M_PI;
		for (float b=sang-0.1;b>eang;b-=0.1) {
			float  cb=cos(b),sb=sin(b);
			float  ux,uy;
			ux=drx+ca*rx*cb-sa*ry*sb;uy=dry+sa*rx*cb+ca*ry*sb;
			float  nw=(sw*(b-eang)+ew*(sang-b))/(sang-eang);
			AddPoint(ux,uy,nw,piece,(sang-b)/(sang-eang));
		}
	} else {
		if ( sang > eang ) sang-=2*M_PI;
		for (float b=sang+0.1;b<eang;b+=0.1) {
			float  cb=cos(b),sb=sin(b);
			float  ux,uy;
			ux=drx+ca*rx*cb-sa*ry*sb;uy=dry+sa*rx*cb+ca*ry*sb;
			float  nw=(sw*(eang-b)+ew*(b-sang))/(eang-sang);
			AddPoint(ux,uy,nw,piece,(b-sang)/(eang-sang));
		}
	}
}
void            Path::RecCubicTo(float sx,float sy,float sdx,float sdy,float ex,float ey,float edx,float edy,float tresh,int lev,float st,float et,int piece)
{
	float dC=sqrt((ex-sx)*(ex-sx)+(ey-sy)*(ey-sy));
	if ( dC < 0.01 ) {
		float sC=sdy*sdy+sdx*sdx;
		float eC=edy*edy+edx*edx;
		if ( sC < tresh && eC < tresh ) return;
	} else {
		float sC=(ex-sx)*sdy-(ey-sy)*sdx;
		float eC=(ex-sx)*edy-(ey-sy)*edx;
		if ( sC < 0 ) sC=-sC;
		if ( eC < 0 ) eC=-eC;
		sC/=dC;
		eC/=dC;
		if ( sC < tresh && eC < tresh ) return;
	}
	
	if ( lev <= 0 ) return;
	
	float   mx,my,mdx,mdy,mt;
	mx=(sx+ex)/2+(sdx-edx)/8;
	my=(sy+ey)/2+(sdy-edy)/8;
	mdx=3*(ex-sx)/4-(sdx+edx)/8;
	mdy=3*(ey-sy)/4-(sdy+edy)/8;
	mt=(st+et)/2;
	
	RecCubicTo(sx,sy,sdx/2,sdy/2,mx,my,mdx,mdy,tresh,lev-1,st,mt,piece);
	AddPoint(mx,my,piece,mt);
	RecCubicTo(mx,my,mdx,mdy,ex,ey,edx/2,edy/2,tresh,lev-1,mt,et,piece);
}
void            Path::RecCubicTo(float sx,float sy,float sw,float sdx,float sdy,float ex,float ey,float ew,float edx,float edy,float tresh,int lev,float st,float et,int piece)
{
	float dC=sqrt((ex-sx)*(ex-sx)+(ey-sy)*(ey-sy));
	if ( dC < 0.01 ) {
		float sC=sdy*sdy+sdx*sdx;
		float eC=edy*edy+edx*edx;
		if ( sC < tresh && eC < tresh ) return;
	} else {
		float sC=(ex-sx)*sdy-(ey-sy)*sdx;
		float eC=(ex-sx)*edy-(ey-sy)*edx;
		if ( sC < 0 ) sC=-sC;
		if ( eC < 0 ) eC=-eC;
		sC/=dC;
		eC/=dC;
		if ( sC < tresh && eC < tresh ) return;
	}
		
	if ( lev <= 0 ) return;
	float   mx,my,mw,mdx,mdy,mt;
	mw=(sw+ew)/2;
	mx=(sx+ex)/2+(sdx-edx)/8;
	my=(sy+ey)/2+(sdy-edy)/8;
	mdx=3*(ex-sx)/4-(sdx+edx)/8;
	mdy=3*(ey-sy)/4-(sdy+edy)/8;
	mt=(st+et)/2;

	RecCubicTo(sx,sy,sw,sdx/2,sdy/2,mx,my,mw,mdx,mdy,tresh,lev-1,st,mt,piece);
	AddPoint(mx,my,mw,piece,mt);
	RecCubicTo(mx,my,mw,mdx,mdy,ex,ey,ew,edx/2,edy/2,tresh,lev-1,mt,et,piece);
}
void            Path::RecBezierTo(float px,float py,float sx,float sy,float ex,float ey,float tresh,int lev,float st,float et,int piece)
{
	if ( lev <= 0 ) return ;
	float s=(sx-px)*(ey-py)-(sy-py)*(ex-px);
	if ( s < 0 ) s=-s;
	if ( s < tresh ) return ;
	
	float   mx,my,mdx,mdy,mt;
	mx=(sx+ex+2*px)/4;
	my=(sy+ey+2*py)/4;
	mdx=(sx+px)/2;
	mdy=(sy+py)/2;
	mt=(st+et)/2;
	RecBezierTo(mdx,mdy,sx,sy,mx,my,tresh,lev-1,st,mt,piece);
	AddPoint(mx,my,piece,mt);
	mdx=(ex+px)/2;
	mdy=(ey+py)/2;
	RecBezierTo(mdx,mdy,mx,my,ex,ey,tresh,lev-1,mt,et,piece);	
}
void            Path::RecBezierTo(float px,float py,float pw,float sx,float sy,float sw,float ex,float ey,float ew,float tresh,int lev,float st,float et,int piece)
{
	if ( lev <= 0 ) return;
	float s=(sx-px)*(ey-py)-(sy-py)*(ex-px);
	if ( s < 0 ) s=-s;
	if ( s < tresh ) return;

	float   mx,my,mw,mdx,mdy,mdw,mt;
	mx=(sx+ex+2*px)/4;
	my=(sy+ey+2*py)/4;
	mw=(sw+ew+2*pw)/4;
	mdx=(sx+px)/2;
	mdy=(sy+py)/2;
	mdw=(sw+pw)/2;
	mt=(st+et)/2;
	RecBezierTo(mdx,mdy,mdw,sx,sy,sw,mx,my,mw,tresh,lev-1,st,mt,piece);
	AddPoint(mx,my,mw,piece,mt);
	mdx=(ex+px)/2;
	mdy=(ey+py)/2;
	mdw=(ew+pw)/2;
	RecBezierTo(mdx,mdy,mdw,mx,my,mw,ex,ey,ew,tresh,lev-1,mt,et,piece);
}

void            Path::DoArc(float sx,float sy,float ex,float ey,float rx,float ry,float angle,bool large,bool wise,float tresh,int piece,offset_orig& orig)
{
	// on n'arrivera jamais ici, puisque les offsets sont fait de cubiques
	if ( rx <= 0.0001 || ry <= 0.0001 ) return; // on ajoute toujours un lineto apres, donc c bon
	
	float   sex=ex-sx,sey=ey-sy;
	float   ca=cos(angle),sa=sin(angle);
	float   csex=ca*sex+sa*sey,csey=-sa*sex+ca*sey;
	csex/=rx;csey/=ry;
	float   l=csex*csex+csey*csey;
	if ( l >= 4 ) l=4;
	float   d=1-l/4;
	if ( d < 0 ) d=0;
	d=sqrt(d);
	float   csdx=csey,csdy=-csex;
	l=sqrt(l);
	csdx/=l;csdy/=l;
	csdx*=d;csdy*=d;

	float   sang,eang;
	float   rax=-csdx-csex/2,ray=-csdy-csey/2;
	if ( rax < -1 ) {
		sang=M_PI;
	} else if ( rax > 1 ) {
		sang=0;
	} else {
		sang=acos(rax);
		if ( ray < 0 ) sang=2*M_PI-sang;
	}
	rax=-csdx+csex/2;ray=-csdy+csey/2;
	if ( rax < -1 ) {
		eang=M_PI;
	} else if ( rax > 1 ) {
		eang=0;
	} else {
		eang=acos(rax);
		if ( ray < 0 ) eang=2*M_PI-eang;
	}
	
	csdx*=rx;csdy*=ry;
	float   drx=ca*csdx-sa*csdy,dry=sa*csdx+ca*csdy;

	if ( wise ) {
		if ( large == true ) {
			drx=-drx;dry=-dry;
			float  swap=eang;eang=sang;sang=swap;
			eang+=M_PI;sang+=M_PI;
			if ( eang >= 2*M_PI ) eang-=2*M_PI;
			if ( sang >= 2*M_PI ) sang-=2*M_PI;
		}
	} else {
		if ( large == false ) {
			drx=-drx;dry=-dry;
			float  swap=eang;eang=sang;sang=swap;
			eang+=M_PI;sang+=M_PI;
			if ( eang >= 2*M_PI ) eang-=2*M_PI;
			if ( sang >= 2*M_PI ) sang-=2*M_PI;
		}
	}
	drx+=(sx+ex)/2;dry+=(sy+ey)/2;

	if ( wise ) {
		if ( sang < eang ) sang+=2*M_PI;
		for (float b=sang-0.1;b>eang;b-=0.1) {
			float  cb=cos(b),sb=sin(b);
			float  ux,uy;
			ux=drx+ca*rx*cb-sa*ry*sb;uy=dry+sa*rx*cb+ca*ry*sb;
			AddPoint(ux,uy,piece,(sang-b)/(sang-eang));
		}
	} else {
		if ( sang > eang ) sang-=2*M_PI;
		for (float b=sang+0.1;b<eang;b+=0.1) {
			float  cb=cos(b),sb=sin(b);
			float  ux,uy;
			ux=drx+ca*rx*cb-sa*ry*sb;uy=dry+sa*rx*cb+ca*ry*sb;
			AddPoint(ux,uy,piece,(b-sang)/(eang-sang));
		}
	}
}
void            Path::RecCubicTo(float sx,float sy,float sdx,float sdy,float ex,float ey,float edx,float edy,float tresh,int lev,float st,float et,int piece,offset_orig& orig)
{
	float dC=sqrt((ex-sx)*(ex-sx)+(ey-sy)*(ey-sy));
	bool  doneSub=false;
	if ( dC < 0.01 ) {
		float sC=sdy*sdy+sdx*sdx;
		float eC=edy*edy+edx*edx;
		if ( sC < tresh && eC < tresh ) doneSub=true;
	} else {
		float sC=(ex-sx)*sdy-(ey-sy)*sdx;
		float eC=(ex-sx)*edy-(ey-sy)*edx;
		if ( sC < 0 ) sC=-sC;
		if ( eC < 0 ) eC=-eC;
		sC/=dC;
		eC/=dC;
		if ( sC < tresh && eC < tresh ) doneSub=true;
	}
	
	if ( lev <= 0 ) doneSub=true;
	
	// test des inversions
	bool stInv=false,enInv=false;
	{
		vec2  os_pos,os_tgt,oe_pos,oe_tgt,om_pos,om_tgt/*,n_tgt*/,os_nor,om_nor,oe_nor;
		vec2  ns_pos,nm_pos,ne_pos,ns_tgt,nm_tgt;
		orig.orig->PointAndTangentAt(orig.piece,orig.tSt*(1-st)+orig.tEn*st,os_pos,os_tgt);
		orig.orig->PointAndTangentAt(orig.piece,orig.tSt*(1-(0.5*et+0.5*st))+orig.tEn*(0.5*et+0.5*st),om_pos,om_tgt);
		orig.orig->PointAndTangentAt(orig.piece,orig.tSt*(1-et)+orig.tEn*et,oe_pos,oe_tgt);
		RotCWTo(os_tgt,os_nor);
		RotCWTo(om_tgt,om_nor);
		RotCWTo(oe_tgt,oe_nor);
		
		ns_pos.x=os_pos.x+orig.off_dec*os_nor.x;
		ns_pos.y=os_pos.y+orig.off_dec*os_nor.y;
		nm_pos.x=om_pos.x+orig.off_dec*om_nor.x;
		nm_pos.y=om_pos.y+orig.off_dec*om_nor.y;
		ne_pos.x=oe_pos.x+orig.off_dec*oe_nor.x;
		ne_pos.y=oe_pos.y+orig.off_dec*oe_nor.y;

		ns_tgt.x=nm_pos.x-ns_pos.x;
		ns_tgt.y=nm_pos.y-ns_pos.y;
		nm_tgt.x=ne_pos.x-nm_pos.x;
		nm_tgt.y=ne_pos.y-nm_pos.y;
		
		Normalize(ns_tgt);
		Normalize(nm_tgt);
		
		vec2 i_biss;
		vec2 f_biss;
		i_biss.x=om_tgt.x-os_tgt.x;
		i_biss.y=om_tgt.y-os_tgt.y;
		f_biss.x=nm_tgt.x-ns_tgt.x;
		f_biss.y=nm_tgt.y-ns_tgt.y;
		
/*		i_biss.x=os_pos.x+oe_pos.x-2*om_pos.x;
		i_biss.y=os_pos.y+oe_pos.y-2*om_pos.y;
		f_biss.x=ns_pos.x+ne_pos.x-2*nm_pos.x;
		f_biss.y=ns_pos.y+ne_pos.y-2*nm_pos.y;*/
		
		float invers=Cross(i_biss,f_biss);
		if ( invers < 0 ) stInv=enInv=true;
		
/*		n_tgt.x=sdx;
		n_tgt.y=sdy;
		float si=Cross(n_tgt,os_tgt);
		if ( si < 0 ) stInv=true;
		n_tgt.x=edx;
		n_tgt.y=edy;
		si=Cross(n_tgt,oe_tgt);
		if ( si < 0 ) enInv=true;*/
//		if ( stInv && enInv ) {
		if ( doneSub && stInv && enInv ) {
			AddPoint(os_pos.x,os_pos.y,-1,0.0);
			AddPoint(ex,ey,piece,et);
			AddPoint(sx,sy,piece,st);
			AddPoint(oe_pos.x,oe_pos.y,-1,0.0);
			return;
//		} else if ( ( stInv && !enInv ) || ( !stInv && enInv ) ) {
//			return;
		}
	}
	if ( ( !stInv && !enInv && doneSub ) || lev <= 0 ) return;
	
	float   mx,my,mdx,mdy,mt;
	mx=(sx+ex)/2+(sdx-edx)/8;
	my=(sy+ey)/2+(sdy-edy)/8;
	mdx=3*(ex-sx)/4-(sdx+edx)/8;
	mdy=3*(ey-sy)/4-(sdy+edy)/8;
	mt=(st+et)/2;
	
	RecCubicTo(sx,sy,sdx/2,sdy/2,mx,my,mdx,mdy,tresh,lev-1,st,mt,piece,orig);
	AddPoint(mx,my,piece,mt);
	RecCubicTo(mx,my,mdx,mdy,ex,ey,edx/2,edy/2,tresh,lev-1,mt,et,piece,orig);
}
void            Path::RecBezierTo(float px,float py,float sx,float sy,float ex,float ey,float tresh,int lev,float st,float et,int piece,offset_orig& orig)
{
	bool doneSub=false;
	float s=(sx-px)*(ey-py)-(sy-py)*(ex-px);
	if ( s < 0 ) s=-s;
	if ( s < tresh ) doneSub=true;
	
	if ( lev <= 0 ) return;

	// test des inversions
	bool stInv=false,enInv=false;
	{
		vec2  os_pos,os_tgt,oe_pos,oe_tgt,n_tgt,n_pos;
		float n_len,n_rad;
		path_descr_intermbezierto mid;
		mid.x=px;
		mid.y=py;
		path_descr_bezierto fin;
		fin.nb=1;
		fin.x=ex;
		fin.y=ey;
		
		TangentOnBezAt(0.0,sx,sy,mid,fin,false,n_pos,n_tgt,n_len,n_rad);
		orig.orig->PointAndTangentAt(orig.piece,orig.tSt*(1-st)+orig.tEn*st,os_pos,os_tgt);
		float si=Cross(n_tgt,os_tgt);
		if ( si < 0 ) stInv=true;
		
		TangentOnBezAt(1.0,sx,sy,mid,fin,false,n_pos,n_tgt,n_len,n_rad);
		orig.orig->PointAndTangentAt(orig.piece,orig.tSt*(1-et)+orig.tEn*et,oe_pos,oe_tgt);
		si=Cross(n_tgt,oe_tgt);
		if ( si < 0 ) enInv=true;
		
		if ( stInv && enInv ) {
			AddPoint(os_pos.x,os_pos.y,-1,0.0);
			AddPoint(ex,ey,piece,et);
			AddPoint(sx,sy,piece,st);
			AddPoint(oe_pos.x,oe_pos.y,-1,0.0);
			return;
			//		} else if ( ( stInv && !enInv ) || ( !stInv && enInv ) ) {
			//			return;
			}
	}
	if ( !stInv && !enInv && doneSub ) return;

	float   mx,my,mdx,mdy,mt;
	mx=(sx+ex+2*px)/4;
	my=(sy+ey+2*py)/4;
	mdx=(sx+px)/2;
	mdy=(sy+py)/2;
	mt=(st+et)/2;
	RecBezierTo(mdx,mdy,sx,sy,mx,my,tresh,lev-1,st,mt,piece,orig);
	AddPoint(mx,my,piece,mt);
	mdx=(ex+px)/2;
	mdy=(ey+py)/2;
	RecBezierTo(mdx,mdy,mx,my,ex,ey,tresh,lev-1,mt,et,piece,orig);	
}


/*
 * conversions
 */

void            Path::Fill(Shape* dest,int pathID,bool justAdd,bool closeIfNeeded,bool invert)
{
	if ( dest == NULL ) return;
	if ( justAdd == false ) {
		dest->Reset(nbPt,nbPt);
	}
	if ( nbPt <= 1 ) return;
	int   first=dest->nbPt;
//	bool  startIsEnd=false;
	
	if ( back ) dest->MakeBackData(true);
	
	if ( invert ) {
	} else {
		if ( back ) {
			if ( weighted ) {
				// !invert && back && weighted
				for (int i=0;i<nbPt;i++) dest->AddPoint(((path_lineto_wb*)pts)[i].x,((path_lineto_wb*)pts)[i].y);
				int               lastM=0;
				int								curP=1;
				int               pathEnd=0;
				bool              closed=false;
				int               lEdge=-1;
				while ( curP < nbPt ) {
					path_lineto_wb*    sbp=((path_lineto_wb*)pts)+curP;
					path_lineto_wb*    lm=((path_lineto_wb*)pts)+lastM;
					path_lineto_wb*    prp=((path_lineto_wb*)pts)+pathEnd;
					if ( sbp->isMoveTo == polyline_moveto ) {
						if ( closeIfNeeded ) {
							if ( closed && lEdge >= 0 ) {
								dest->DisconnectEnd(lEdge);
								dest->ConnectEnd(first+lastM,lEdge);
							} else {
								dest->AddEdge(first+pathEnd,first+lastM);
								dest->ebData[lEdge].pathID=pathID;
								dest->ebData[lEdge].pieceID=lm->piece;
								dest->ebData[lEdge].tSt=0.0;
								dest->ebData[lEdge].tEn=1.0;
							}
						}
						lastM=curP;
						pathEnd=curP;
						closed=false;
						lEdge=-1;
					} else {
						if ( fabs(sbp->x-prp->x) < 0.00001 && fabs(sbp->y-prp->y) < 0.00001 ) {
						} else {
							lEdge=dest->AddEdge(first+pathEnd,first+curP);
							dest->ebData[lEdge].pathID=pathID;
							dest->ebData[lEdge].pieceID=sbp->piece;
							if ( sbp->piece == prp->piece ) {
								dest->ebData[lEdge].tSt=prp->t;
								dest->ebData[lEdge].tEn=sbp->t;
							} else {
								dest->ebData[lEdge].tSt=0.0;
								dest->ebData[lEdge].tEn=1.0;
							}
							pathEnd=curP;
							if ( fabs(sbp->x-lm->x) < 0.00001 && fabs(sbp->y-lm->y) < 0.00001 ) {
								closed=true;
							} else {
								closed=false;
							}
						}
					}
					curP++;
				}
				if ( closeIfNeeded ) {
					if ( closed && lEdge >= 0 ) {
						dest->DisconnectEnd(lEdge);
						dest->ConnectEnd(first+lastM,lEdge);
					} else {
						path_lineto_wb*    lm=((path_lineto_wb*)pts)+lastM;
						lEdge=dest->AddEdge(first+pathEnd,first+lastM);
						dest->ebData[lEdge].pathID=pathID;
						dest->ebData[lEdge].pieceID=lm->piece;
						dest->ebData[lEdge].tSt=0.0;
						dest->ebData[lEdge].tEn=1.0;
					}
				}
			} else {
				// !invert && back && !weighted
				for (int i=0;i<nbPt;i++) dest->AddPoint(((path_lineto_b*)pts)[i].x,((path_lineto_b*)pts)[i].y);
				int               lastM=0;
				int								curP=1;
				int               pathEnd=0;
				bool              closed=false;
				int               lEdge=-1;
				while ( curP < nbPt ) {
					path_lineto_b*    sbp=((path_lineto_b*)pts)+curP;
					path_lineto_b*    lm=((path_lineto_b*)pts)+lastM;
					path_lineto_b*    prp=((path_lineto_b*)pts)+pathEnd;
					if ( sbp->isMoveTo == polyline_moveto ) {
						if ( closeIfNeeded ) {
							if ( closed && lEdge >= 0 ) {
								dest->DisconnectEnd(lEdge);
								dest->ConnectEnd(first+lastM,lEdge);
							} else {
								dest->AddEdge(first+pathEnd,first+lastM);
								dest->ebData[lEdge].pathID=pathID;
								dest->ebData[lEdge].pieceID=lm->piece;
								dest->ebData[lEdge].tSt=0.0;
								dest->ebData[lEdge].tEn=1.0;
							}
						}
						lastM=curP;
						pathEnd=curP;
						closed=false;
						lEdge=-1;
					} else {
						if ( fabs(sbp->x-prp->x) < 0.00001 && fabs(sbp->y-prp->y) < 0.00001 ) {
						} else {
							lEdge=dest->AddEdge(first+pathEnd,first+curP);
							dest->ebData[lEdge].pathID=pathID;
							dest->ebData[lEdge].pieceID=sbp->piece;
							if ( sbp->piece == prp->piece ) {
								dest->ebData[lEdge].tSt=prp->t;
								dest->ebData[lEdge].tEn=sbp->t;
							} else {
								dest->ebData[lEdge].tSt=0.0;
								dest->ebData[lEdge].tEn=sbp->t;
							}
							pathEnd=curP;
							if ( fabs(sbp->x-lm->x) < 0.00001 && fabs(sbp->y-lm->y) < 0.00001 ) {
								closed=true;
							} else {
								closed=false;
							}
						}
					}
					curP++;
				}
				if ( closeIfNeeded ) {
					if ( closed && lEdge >= 0 ) {
						dest->DisconnectEnd(lEdge);
						dest->ConnectEnd(first+lastM,lEdge);
					} else {
						path_lineto_b*    lm=((path_lineto_b*)pts)+lastM;
						lEdge=dest->AddEdge(first+pathEnd,first+lastM);
						dest->ebData[lEdge].pathID=pathID;
						dest->ebData[lEdge].pieceID=lm->piece;
						dest->ebData[lEdge].tSt=0.0;
						dest->ebData[lEdge].tEn=1.0;
					}
				}
			}
		} else {
			if ( weighted ) {
				// !invert && !back && weighted
				for (int i=0;i<nbPt;i++) dest->AddPoint(((path_lineto_w*)pts)[i].x,((path_lineto_w*)pts)[i].y);
				int               lastM=0;
				int								curP=1;
				int               pathEnd=0;
				bool              closed=false;
				int               lEdge=-1;
				while ( curP < nbPt ) {
					path_lineto_w*    sbp=((path_lineto_w*)pts)+curP;
					path_lineto_w*    lm=((path_lineto_w*)pts)+lastM;
					path_lineto_w*    prp=((path_lineto_w*)pts)+pathEnd;
					if ( sbp->isMoveTo == polyline_moveto ) {
						if ( closeIfNeeded ) {
							if ( closed && lEdge >= 0 ) {
								dest->DisconnectEnd(lEdge);
								dest->ConnectEnd(first+lastM,lEdge);
							} else {
								dest->AddEdge(first+pathEnd,first+lastM);
							}
						}
						lastM=curP;
						pathEnd=curP;
						closed=false;
						lEdge=-1;
					} else {
						if ( fabs(sbp->x-prp->x) < 0.00001 && fabs(sbp->y-prp->y) < 0.00001 ) {
						} else {
							lEdge=dest->AddEdge(first+pathEnd,first+curP);
							pathEnd=curP;
							if ( fabs(sbp->x-lm->x) < 0.00001 && fabs(sbp->y-lm->y) < 0.00001 ) {
								closed=true;
							} else {
								closed=false;
							}
						}
					}
					curP++;
				}
				
				if ( closeIfNeeded ) {
					if ( closed && lEdge >= 0 ) {
						dest->DisconnectEnd(lEdge);
						dest->ConnectEnd(first+lastM,lEdge);
					} else {
						dest->AddEdge(first+pathEnd,first+lastM);
					}
				}
			} else {
				// !invert && !back && !weighted
				for (int i=0;i<nbPt;i++) dest->AddPoint(((path_lineto*)pts)[i].x,((path_lineto*)pts)[i].y);
				int               lastM=0;
				int								curP=1;
				int               pathEnd=0;
				bool              closed=false;
				int               lEdge=-1;
				while ( curP < nbPt ) {
					path_lineto*    sbp=((path_lineto*)pts)+curP;
					path_lineto*    lm=((path_lineto*)pts)+lastM;
					path_lineto*    prp=((path_lineto*)pts)+pathEnd;
					if ( sbp->isMoveTo == polyline_moveto ) {
						if ( closeIfNeeded ) {
							if ( closed && lEdge >= 0 ) {
								dest->DisconnectEnd(lEdge);
								dest->ConnectEnd(first+lastM,lEdge);
							} else {
								dest->AddEdge(first+pathEnd,first+lastM);
							}
						}
						lastM=curP;
						pathEnd=curP;
						closed=false;
						lEdge=-1;
					} else {
						if ( fabs(sbp->x-prp->x) < 0.00001 && fabs(sbp->y-prp->y) < 0.00001 ) {
						} else {
							lEdge=dest->AddEdge(first+pathEnd,first+curP);
							pathEnd=curP;
							if ( fabs(sbp->x-lm->x) < 0.00001 && fabs(sbp->y-lm->y) < 0.00001 ) {
								closed=true;
							} else {
								closed=false;
							}
						}
					}
					curP++;
				}
				
				if ( closeIfNeeded ) {
					if ( closed && lEdge >= 0 ) {
						dest->DisconnectEnd(lEdge);
						dest->ConnectEnd(first+lastM,lEdge);
					} else {
						dest->AddEdge(first+pathEnd,first+lastM);
					}
				}
				
			}
		}
	}
}
