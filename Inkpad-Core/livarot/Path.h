/*
 *  Path.h
 *  nlivarot
 *
 *  Created by fred on Tue Jun 17 2003.
 *
 */

#ifndef my_path
#define my_path

#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
//#include <iostream.h>

#include "LivarotDefs.h"
#include "MyMath.h"

enum {
	descr_moveto         =0,
	descr_lineto         =1,
	descr_cubicto        =2,
	descr_bezierto       =3,
	descr_arcto          =4,
	descr_close					 =5,
	descr_interm_bezier  =6,
	descr_forced         =7,
	
	descr_type_mask      =15,
	
	descr_weighted       =16
};

enum {
	polyline_lineto      =0,
	polyline_moveto      =1,
	polyline_forced      =2
};

class Shape;
class Region;

typedef struct dashTo_info {
		float nDashAbs;
		vec2 prevP;
		vec2 curP;
		vec2 prevD;
		float prevW;
		float curW;
} dashTo_info;

// path creation: 2 phases: first the path is given as a succession of commands (MoveTo, LineTo, CurveTo...); then it
// is converted in a polyline
// a polylone can be stroked or filled to make a polygon
class Path {
	friend class Shape;
public:
	// command list structures

	// lineto: a point, maybe with a weight
	typedef struct path_descr_moveto {
		float        x,y;
		int          pathLength; // number of description for this subpath
	} path_descr_moveto;
	
	typedef struct path_descr_moveto_w : public path_descr_moveto {
		float        w;
	} path_descr_moveto_w;
	
	// lineto: a point, maybe with a weight
	// MoveTos fit in this category
	typedef struct path_descr_lineto{
		float        x,y;
	} path_descr_lineto;
	typedef struct path_descr_lineto_w : public path_descr_lineto {
		float        w;
	} path_descr_lineto_w;
	
	// quadratic bezier curves: a set of control points, and an endpoint
	typedef struct path_descr_bezierto {
		int          nb;
		float        x,y; // the endpoint's coordinates
	} path_descr_bezierto;
	typedef struct path_descr_bezierto_w : public path_descr_bezierto {
		float        w;
	} path_descr_bezierto_w;
	typedef struct path_descr_intermbezierto {
		float        x,y; // controm point coordinates
	} path_descr_intermbezierto;
	typedef struct path_descr_intermbezierto_w : public path_descr_intermbezierto {
		float        w;
	} path_descr_intermbezierto_w;

	// cubic spline curve: 2 tangents and one endpoint
	typedef struct path_descr_cubicto {
		float        x,y;
		float        stDx,stDy;
		float        enDx,enDy;
	} path_descr_cubicto;
	typedef struct path_descr_cubicto_w : public path_descr_cubicto {
		float        w; // weight for the endpoint (if any)
	} path_descr_cubicto_w;

	// arc: endpoint, 2 radii and one angle, plus 2 booleans to choose the arc (svg style)
	typedef struct path_descr_arcto {
		float        x,y;
		float        rx,ry,angle;
		bool         large,clockwise;
	} path_descr_arcto;
	typedef struct path_descr_arcto_w : public path_descr_arcto {
		float        w; // weight for the endpoint (if any)
	} path_descr_arcto_w;
	
	typedef struct path_descr {
		int           flags;
		int						associated; // le no du moveto/lineto dans la polyligne. ou alors no de la piece dans l'original
		float         tSt,tEn;
		union {
			path_descr_moveto_w          m;
			path_descr_lineto_w          l;
			path_descr_cubicto_w         c;
			path_descr_arcto_w					 a;
			path_descr_bezierto_w        b;
			path_descr_intermbezierto_w  i;
		} d;
	} path_descr;
	
	enum {
		descr_ready            =0,
		descr_adding_bezier    =1,
		descr_doing_subpath    =2,
		descr_delayed_bezier	 =4,
		descr_dirty            =16
	};
public:
	int             descr_flags;
	int             descr_max,descr_nb;
	path_descr*		  descr_data;
	int             pending_bezier;
	int             pending_moveto;

	// polyline storage: a serie of coordinates (and maybe weights)
	typedef struct path_lineto {
		int          isMoveTo;
		float        x,y;
	} path_lineto;
	typedef struct path_lineto_w : public path_lineto {
		float        w;
	} path_lineto_w;
	typedef struct path_lineto_b : public path_lineto {
		int          piece;
		float        t;
	} path_lineto_b;
	typedef struct path_lineto_wb : public path_lineto_w {
		int          piece;
		float        t;
	} path_lineto_wb;
	
public:
	bool            weighted;
	bool            back;
	int             nbPt,maxPt,sizePt;
	char*           pts;
		
	Path(void);
	~Path(void);

	// creation of the path description
	void            Reset(void); // reset to the empty description
	void            Copy(Path* who);
	
	// dumps the path description on the standard output
	void					  Affiche(void);

	// the commands...
	int            ForcePoint(void);
	int            Close(void);
	int            MoveTo(float ix,float iy);
	int            MoveTo(float ix,float iy,float iw);
	int            LineTo(float ix,float iy);
	int            LineTo(float ix,float iy,float iw);
	int            CubicTo(float ix,float iy,float isDx,float isDy,float ieDx,float ieDy);
	int            CubicTo(float ix,float iy,float isDx,float isDy,float ieDx,float ieDy,float iw);
	int            ArcTo(float ix,float iy,float iRx,float iRy,float angle,bool iLargeArc,bool iClockwise);
	int            ArcTo(float ix,float iy,float iRx,float iRy,float angle,bool iLargeArc,bool iClockwise,float iw);
	int            IntermBezierTo(float ix,float iy); // add a quadratic bezier spline control point
	int            IntermBezierTo(float ix,float iy,float iw);
	int            BezierTo(float ix,float iy); // quadratic bezier spline to this point (control points can be added after this)
	int            BezierTo(float ix,float iy,float iw);
	int            TempBezierTo(void); // start a quadratic bezier spline (control points can be added after this)
	int            TempBezierToW(void);
	int            EndBezierTo(void);
	int            EndBezierTo(float ix,float iy);  // ends a quadratic bezier spline (for curves started with TempBezierTo)
	int            EndBezierTo(float ix,float iy,float iw);
	
	// transforms a description in a polyline (for stroking and filling)
	// treshhold is the max length^2 (sort of)
	void            Convert(float treshhold);
	void            ConvertEvenLines(float treshhold); // decomposes line segments too, for later recomposition
	// same function for use when you want to later recompose the curves from the polyline
	void            ConvertWithBackData(float treshhold);
	 // same function for use when you want to later recompose the curves from the polyline
	void            ConvertForOffset(float treshhold,Path* orig,float off_dec);

	// creation of the polyline (you can tinker with these function if you want)
	void            SetWeighted(bool nVal); // is weighted?
	void            SetBackData(bool nVal); // has back data?
	void            ResetPoints(int expected=0); // resets to the empty polyline
	int             AddPoint(float ix,float iy,bool mvto=false); // add point
	int             AddPoint(float ix,float iy,float iw,bool mvto=false);
	int             AddPoint(float ix,float iy,int ip,float it,bool mvto=false);
	int             AddPoint(float ix,float iy,float iw,int ip,float it,bool mvto=false);
	int             AddForcedPoint(float ix,float iy); // add point
	int             AddForcedPoint(float ix,float iy,float iw);
	int             AddForcedPoint(float ix,float iy,int ip,float it);
	int             AddForcedPoint(float ix,float iy,float iw,int ip,float it);
	
	// transform in a polygon (in a graph, in fact; a subsequent call to ConvertToShape is needed)
	//  - fills the polyline; justAdd=true doesn't reset the Shape dest, but simply adds the polyline into it
	// closeIfNeeded=false prevent the function from closing the path (resulting in a non-eulerian graph
	// pathID is a identification number for the path, and is used for recomposing curves from polylines
	// give each different Path a different ID, and feed the appropriate orig[] to the ConvertToForme() function
	void            Fill(Shape* dest,int pathID=-1,bool justAdd=false,bool closeIfNeeded=true,bool invert=false);
	// - stroke the path; usual parameters: type of cap=butt, type of join=join and miter (see LivarotDefs.h)
	// doClose treat the path as closed (ie a loop)
	void            Stroke(Shape* dest,bool doClose,float width,JoinType join,ButtType butt,float miter,bool justAdd=false);
	// strokes the Path in a region (ready to rasterize)
	void            Stroke(Region* dest,bool doClose,float width,JoinType join,ButtType butt,float miter);
	// stroke with dashes
	void            Stroke(Shape* dest,bool doClose,float width,JoinType join,ButtType butt,float miter,int nbDash,one_dash* dashs,bool justAdd=false);
	// build a Path that is the outline of the Path instance's description (the result is stored in dest)
	// it doesn't compute the exact offset (it's way too complicated, but an approximation made of cubic bezier patches
	//  and segments. the algorithm was found in a plugin for Impress (by Chris Cox), but i can't find it back...
	void						Outline(Path* dest,float width,JoinType join,ButtType butt,float miter);
	// half outline with edges having the same direction as the original
	void            OutsideOutline(Path* dest,float width,JoinType join,ButtType butt,float miter);
	// half outline with edges having the opposite direction as the original
	void            InsideOutline(Path* dest,float width,JoinType join,ButtType butt,float miter);
	
	// polyline to cubic bezier
	void            Simplify(float treshhold);
	// description simplification
	void            Coalesce(float tresh);
	
	// utilities
	void            PointAt(int piece,float at,vec2 &pos);
	void            PointAndTangentAt(int piece,float at,vec2 &pos,vec2 &tgt);

	void						PrevPoint(int i,float &x,float &y);
private:
	void            Alloue(int addSize);
	void            CancelBezier(void);
	void            CloseSubpath(int add);
	// winding of the path (treated as a loop)
	int             Winding(void);	
	
	// fonctions utilisees par la conversion
	void            DoArc(float sx,float sy,float ex,float ey,float rx,float ry,float angle,bool large,bool wise,float tresh);
	void            DoArc(float sx,float sy,float sw,float ex,float ey,float ew,float rx,float ry,float angle,bool large,bool wise,float tresh);
	void            RecCubicTo(float sx,float sy,float sdx,float sdy,float ex,float ey,float edx,float edy,float tresh,int lev,float maxL=-1.0);
	void            RecCubicTo(float sx,float sy,float sw,float sdx,float sdy,float ex,float ey,float ew,float edx,float edy,float tresh,int lev,float maxL=-1.0);
	void            RecBezierTo(float px,float py,float sx,float sy,float ex,float ey,float treshhold,int lev,float maxL=-1.0);
	void            RecBezierTo(float px,float py,float pw,float sx,float sy,float sw,float ex,float ey,float ew,float treshhold,int lev,float maxL=-1.0);
	
	void						DoArc(float sx,float sy,float ex,float ey,float rx,float ry,float angle,bool large,bool wise,float tresh,int piece);
	void            DoArc(float sx,float sy,float sw,float ex,float ey,float ew,float rx,float ry,float angle,bool large,bool wise,float tresh,int piece);
	void            RecCubicTo(float sx,float sy,float sdx,float sdy,float ex,float ey,float edx,float edy,float tresh,int lev,float st,float et,int piece);
	void            RecCubicTo(float sx,float sy,float sw,float sdx,float sdy,float ex,float ey,float ew,float edx,float edy,float tresh,int lev,float st,float et,int piece);
	void            RecBezierTo(float px,float py,float sx,float sy,float ex,float ey,float treshhold,int lev,float st,float et,int piece);
	void            RecBezierTo(float px,float py,float pw,float sx,float sy,float sw,float ex,float ey,float ew,float treshhold,int lev,float st,float et,int piece);

	typedef struct offset_orig {
		Path* orig;
		int   piece;
		float tSt,tEn;
		float off_dec;
	} offset_orig;
	void						DoArc(float sx,float sy,float ex,float ey,float rx,float ry,float angle,bool large,bool wise,float tresh,int piece,offset_orig& orig);
	void            RecCubicTo(float sx,float sy,float sdx,float sdy,float ex,float ey,float edx,float edy,float tresh,int lev,float st,float et,int piece,offset_orig& orig);
	void            RecBezierTo(float px,float py,float sx,float sy,float ex,float ey,float treshhold,int lev,float st,float et,int piece,offset_orig& orig);
		
	static void     ArcAngles(float sx,float sy,float ex,float ey,float rx,float ry,float angle,bool large,bool wise,float &sang,float &eang);
	static void     QuadraticPoint(float t,float &ox,float &oy,float sx,float sy,float mx,float my,float ex,float ey);
	static void     CubicTangent(float t,float &ox,float &oy,float sx,float sy,float sdx,float sdy,float ex,float ey,float edx,float edy);
			
	typedef struct outline_callback_data {
		Path*         orig;
		int           piece;
		float         tSt,tEn;
		Path*         dest;
		float         x1,y1,x2,y2;
		union {
			struct {
				float     dx1,dy1,dx2,dy2;
			} c;
			struct {
				float     mx,my;
			} b;
			struct {
				float     rx,ry,angle;
				bool      clock,large;
				float     stA,enA;
			} a;
		} d;
	} outline_callback_data;

	typedef void (outlineCallback) (outline_callback_data *data,float tol,float width);
	typedef struct outline_callbacks {
		outlineCallback   *cubicto;
		outlineCallback   *bezierto;
		outlineCallback   *arcto;
	} outline_callbacks;
		
	void						SubContractOutline(Path* dest,outline_callbacks &calls,float tolerance,float width,JoinType join,ButtType butt,float miter,bool closeIfNeeded,bool skipMoveto,vec2 &lastP,vec2 &lastT);
	void            DoOutsideOutline(Path* dest,float width,JoinType join,ButtType butt,float miter,int &stNo,int &enNo);
	void            DoInsideOutline(Path* dest,float width,JoinType join,ButtType butt,float miter,int &stNo,int &enNo);
	void            DoStroke(Shape* dest,bool doClose,float width,JoinType join,ButtType butt,float miter,bool justAdd=false);
	void            DoStroke(Region* dest,bool doClose,float width,JoinType join,ButtType butt,float miter);
	void            DoStroke(Shape* dest,bool doClose,float width,JoinType join,ButtType butt,float miter,int nbDash,one_dash* dashs,bool justAdd=false);
	
	static void     TangentOnSegAt(float at,float sx,float sy,path_descr_lineto& fin,vec2& pos,vec2& tgt,float &len);
	static void     TangentOnArcAt(float at,float sx,float sy,path_descr_arcto& fin,vec2& pos,vec2& tgt,float &len,float &rad);
	static void     TangentOnCubAt(float at,float sx,float sy,path_descr_cubicto& fin,bool before,vec2& pos,vec2& tgt,float &len,float &rad);
	static void     TangentOnBezAt(float at,float sx,float sy,path_descr_intermbezierto& mid,path_descr_bezierto& fin,bool before,vec2& pos,vec2& tgt,float &len,float &rad);
	static void     OutlineJoin(Path* dest,vec2 pos,vec2 stNor,vec2 enNor,float width,JoinType join,float miter);
	
	static bool			IsNulCurve(path_descr* curD,float curX,float curY);

	static void RecStdCubicTo(outline_callback_data *data,float tol,float width,int lev);
	static void StdCubicTo(outline_callback_data *data,float tol,float width);
	static void StdBezierTo(outline_callback_data *data,float tol,float width);
	static void RecStdArcTo(outline_callback_data *data,float tol,float width,int lev);
	static void StdArcTo(outline_callback_data *data,float tol,float width);


	// fonctions annexes pour le stroke
	static void            DoSeg(Region* dest,float stW,vec2 stPos,float enW,vec2 enPos,vec2 dir);
	static void            DoButt(Region* dest,float width,ButtType butt,vec2 pos,vec2 dir);
	static void            DoJoin(Region* dest,float width,JoinType join,vec2 pos,vec2 prev,vec2 next,float miter,float prevL,float nextL);
	static void            DoButt(Shape* dest,float width,ButtType butt,vec2 pos,vec2 dir,int &leftNo,int &rightNo);
	static void            DoJoin(Shape* dest,float width,JoinType join,vec2 pos,vec2 prev,vec2 next,float miter,float prevL,float nextL,int &leftStNo,int &leftEnNo,int &rightStNo,int &rightEnNo);
	static void            DoLeftJoin(Shape* dest,float width,JoinType join,vec2 pos,vec2 prev,vec2 next,float miter,float prevL,float nextL,int &leftStNo,int &leftEnNo);
	static void            DoRightJoin(Shape* dest,float width,JoinType join,vec2 pos,vec2 prev,vec2 next,float miter,float prevL,float nextL,int &rightStNo,int &rightEnNo);
	static void            RecRound(Shape* dest,int sNo,int eNo,float px,float py,float sx,float sy,float ex,float ey,float tresh,int lev);
	static void            DashTo(Shape* dest,dashTo_info *dTo,float &dashAbs,int& dashNo,float& dashPos,bool& inGap,int& lastLeft,int& lastRight,int nbDash,one_dash* dashs);

	void                   DoCoalesce(Path* dest,float tresh);
	
	void                   DoSimplify(float treshhold);
	bool                   AttemptSimplify(float treshhold,path_descr_cubicto &res);
	float                  RaffineTk(vec2 pt,vec2 p0,vec2 p1,vec2 p2,vec2 p3,float it);
};
#endif
