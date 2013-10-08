/*
 *  Digraph.h
 *  nlivarot
 *
 *  Created by fred on Thu Jun 12 2003.
 *
 */

#ifndef my_shape
#define my_shape

#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
//#include <iostream.h>

#include "ShapeUtils.h"

// possible values for the "type" field in the Shape class:
enum {
	shape_graph           = 0,  // it's just a graph; a bunch of edges, maybe intersections
	shape_polygon         = 1,  // a polygon: intersection-free, edges oriented so that the inside is on their left
	shape_polypatch       = 2   // a graph without intersection; each face is a polygon (not yet used)
};

// possible flags for the "flags" field in the Shape class
// they record which structure is currently allocated, or if the graph is "dirty"
enum {
	need_points_sorting   = 1,   // points have been added or removed: we need to sort the points again
	need_edges_sorting    = 2,   // edges have been added: maybe they are not ordered clockwise
	                             // nota: if you remove an edge, the clockwise order still holds
	has_points_data       = 4,   // the pData array is allocated
	has_edges_data        = 8,   // the eData array is allocated
	has_sweep_src_data    = 16,  // the swsData array is allocated
	has_sweep_dest_data   = 32,  // the swdData array is allocated
	has_sweep_data        = 64,  // the sTree and sEvts structures are allocated
	                             // nota: the size of these structures is determined when they are allocated, and don't
	                             // change after that
	has_raster_data       = 128, // the swrData array is allocated
	has_quick_raster_data = 256, // the swrData array is allocated
	has_back_data					= 512, // the ebData array is allocated
	has_voronoi_data			= 1024
};

class FloatLigne;
class CoverageLigne;
class AlphaLigne;
class BitLigne;
class Path;

class Shape  {
	friend class SweepTree;
	friend class SweepEvent;
public:
	// bounding box stuff
	float            leftX,topY,rightX,bottomY;

	// topological information: who links who?
	typedef struct dg_point {
		float           x,y;          // position
		int             dI,dO;        // indegree and outdegree
		int             firstA,lastA; // first and last incident edge
		int             oldDegree;
	} dg_point;
	typedef struct dg_arete {
		float           dx,dy;        // edge vector
		int             st,en;        // start and end points of the edge
		int             nextS,prevS;  // next and previous edge in the double-linked list at the start point
		int             nextE,prevE;  // next and previous edge in the double-linked list at the end point
	} dg_arete;

	// lists of the nodes and edges
	int               nbPt,maxPt;
	dg_point*         pts;
	int               nbAr,maxAr;
	dg_arete*         aretes;

	// flags
	int               type;
	int               flags;

private:
	// temporary data for the various algorithms
	typedef struct edge_data {
		int              weight;  // weight of the edge (to handle multiple edges)
		float            rdx,rdy; // rounded edge vector
		double           length,sqlength,ilength,isqlength; // length^2, length, 1/length^2, 1/length
		double           siEd,coEd; // siEd=abs(rdy/length) and coEd=rdx/length
		                            // used to determine the "most horizontal" edge between 2 edges
	} edge_data;
	typedef struct sweep_src_data {
		void*            misc;  // pointer to the SweepTree* in the sweepline
		int              firstLinkedPoint; // not used
		int              stPt,enPt; // start- end end- points for this edge in the resulting polygon
		int              ind;       // for the GetAdjacencies function: index in the sliceSegs array (for quick deletions)
		int              leftRnd,rightRnd; // leftmost and rightmost points (in the result polygon) that are incident to
		                                   // the edge, for the current sweep position
																		   // not set if the edge doesn't start/end or intersect at the current sweep position
		Shape*           nextSh;           // nextSh and nextBo identify the next edge in the list
		int              nextBo;           // they are used to maintain a linked list of edge that start/end or intersect at
		                                   // the current sweep position
		int              curPoint,doneTo;
		float						 curT;
	} sweep_src_data;
	typedef struct sweep_dest_data {
		void*            misc;   // used to check if an edge has already been seen during the depth-first search
		int              suivParc,precParc; // previous and current next edge in the depth-first search
		int              leW,riW; // left and right winding numbers for this edge
		int              ind;     // order of the edges during the depth-first search
	} sweep_dest_data;
	typedef struct raster_data {
		SweepTree*       misc; // pointer to the associated SweepTree* in the sweepline
		float            lastX,lastY,curX,curY; // curX;curY is the current intersection of the edge with the sweepline
		                                        // lastX;lastY is the intersection with the previous sweepline
		bool             sens;                  // true if the edge goes down, false otherwise
		float            calcX;                 // horizontal position of the intersection of the edge with the
		                                        // previous sweepline
		float            dxdy,dydx;  // horizontal change per unit vertical move of the intersection with the sweepline
		int              guess;
	} raster_data;
	typedef struct quick_raster_data {
		float            x;    // x-position on the sweepline
		int              bord; // index of the edge
		int              ind;
		bool             process;
	} quick_raster_data;
	typedef struct point_data {
		int              oldInd,newInd; // back and forth indices used when sorting the points, to know where they have
																		// been relocated in the array
		int              pending;       // number of intersection attached to this edge, and also used when sorting arrays
		int              edgeOnLeft;    // not used (should help speeding up winding calculations)
		int              nextLinkedPoint; // not used
		Shape*           askForWindingS;
		int              askForWindingB;
		float            rx,ry; // rounded coordinates of the point
	} point_data;
	typedef struct incidenceData {
		int              nextInc;  // next incidence in the linked list
		int              pt;       // point incident to the edge (there is one list per edge)
		float            theta;    // coordinate of the incidence on the edge
	} incidenceData;
	typedef struct sTreeChange {
		int         type; // type of modification to the sweepline:
		                  // 0=edge inserted
		                  // 1=edge removed
		                  // 2=intersection
		int         ptNo; // point at which the modification takes place

		Shape*      src;  // left edge (or unique edge if not an intersection) involved in the event
		int         bord;
		Shape*      osrc; // right edge (if intersection)
		int         obord;
		Shape*      lSrc; // edge directly on the left in the sweepline at the moment of the event
		int         lBrd;
		Shape*      rSrc; // edge directly on the right
		int         rBrd;
	} sTreeChange;
	typedef struct back_data {
		int         pathID,pieceID;
		float				tSt,tEn;
	} back_data;
	typedef struct voronoi_point {  // info for points treated as points of a voronoi diagram (obtained by MakeShape())
		float       value;   // distance to source
		int         winding; // winding relatively to source
	} voronoi_point;
	typedef struct voronoi_edge { // info for edges, treated as approximation of edges of the voronoi diagram
		int         leF,riF;                 // left and right site
		float       leStX,leStY,riStX,riStY; // on the left side: (leStX,leStY) is the smallest vector from the source to st
		                                     // etc...
		float       leEnX,leEnY,riEnX,riEnY;
	} voronoi_edge;
	
	// the arrays of temporary data
	// these ones are dynamically kept at a length of maxPt or maxAr
	edge_data*       eData;
	sweep_src_data*  swsData;
	sweep_dest_data* swdData;
	raster_data*     swrData;
	point_data*      pData;
public:
	back_data*       ebData;
	voronoi_point*	 vorpData;
	voronoi_edge*	   voreData;

	//private:
	int              nbQRas;
	quick_raster_data* qrsData;
	// these ones are dynamically allocated
	int              nbChgt,maxChgt; 
	sTreeChange*     chgts;
	int              nbInc,maxInc;
	incidenceData*   iData;
	// these ones are defined in ShapeUtils.h, allocated at the beginning of each sweep and freed at the end of the sweep
	SweepTreeList    sTree;
	SweepEventQueue  sEvts;

public:
	Shape(void);
	~Shape(void);


	void              MakeBackData(bool nVal);
	void              MakeVoronoiData(bool nVal);

	// insertion/deletion/movement of elements in the graph
	void              Copy(Shape* a);
	// -reset the graph, and ensure there's room for n points and m edges
	void              Reset(int n=0,int m=0);
	//  -points:
	int               AddPoint(float x,float y); // as the function name says
																							 // returns the index at which the point has been added in the array
	void              SubPoint(int p);           // removes the point at index p
	                                             // nota: this function relocates the last point to the index p
	                                             // so don't trust point indices if you use SubPoint
	void              SwapPoints(int a,int b);   // swaps 2 points at indices a and b
	void              SwapPoints(int a,int b,int c); // swaps 3 points: c <- a <- b <- c
	void              SortPoints(void);          // sorts the points if needed (checks the need_points_sorting flag)

	//  -edges:
	int               AddEdge(int st,int en); // add an edge between points of indices st and en
																						// return the edge index in the array
	int               AddEdge(int st,int en,int leF,int riF); // add an edge between points of indices st and en
	                                          // return the edge index in the array
	                                          // version for the voronoi (with faces IDs)
	void              SubEdge(int e);         // removes the edge at index e (same remarks as for SubPoint)
	void              SwapEdges(int a,int b); // swaps 2 edges
	void              SwapEdges(int a,int b,int c); // swaps 3 edges
	void              SortEdges(void); // sort the edges if needed (checks the need_edges_sorting falg)

	// primitives for topological manipulations
	inline int               Other(int p,int b) // endpoint of edge at index b that is different from the point p
	{
		if ( aretes[b].st == p ) return aretes[b].en;
		return aretes[b].st;
	};
	inline int               NextAt(int p,int b) // next edge (after edge b) in the double-linked list at point p
	{
		if ( p == aretes[b].st ) {
			return aretes[b].nextS;
		} else if ( p == aretes[b].en ) {
			return aretes[b].nextE;
		}
		return -1;
	};
	inline int               PrevAt(int p,int b) // previous edge
	{
		if ( p == aretes[b].st ) {
			return aretes[b].prevS;
		} else if ( p == aretes[b].en ) {
			return aretes[b].prevE;
		}
		return -1;
	};
	inline int               CycleNextAt(int p,int b) // same as NextAt, but the list is considered circular
	{
		if ( p == aretes[b].st ) {
			if ( aretes[b].nextS < 0 ) return pts[p].firstA;
			return aretes[b].nextS;
		} else if ( p == aretes[b].en ) {
			if ( aretes[b].nextE < 0 ) return pts[p].firstA;
			return aretes[b].nextE;
		}
		return -1;
	};
	inline int               CyclePrevAt(int p,int b) // same as PrevAt, but the list is considered circular
	{
		if ( p == aretes[b].st ) {
			if ( aretes[b].prevS < 0 ) return pts[p].lastA;
			return aretes[b].prevS;
		} else if ( p == aretes[b].en ) {
			if ( aretes[b].prevE < 0 ) return pts[p].lastA;
			return aretes[b].prevE;
		}
		return -1;
	};
	void              ConnectStart(int p,int b); // set the point p as the start of edge b
	void              ConnectEnd(int p,int b);   // set the point p as the end of edge b
	void              DisconnectStart(int b); // disconnect edge b from its start point
	void              DisconnectEnd(int b);   // disconnect edge b from its end point

	// miscanellous routines
	void              Inverse(int b); // reverses edge b (start <-> end)
	bool              Eulerian(bool directed); // is the graph eulerian, considered directed if directed=true and
	                                           // undirected if not?
																						// nota: a polygon is always eulerian
	void              CalcBBox(void);          // calc bounding box and sets leftX,rightX,topY and bottomY to their values

	// debug function: plots the graph (mac only)
	void              Plot(float ix,float iy,float ir,float mx,float my,bool doPoint,bool edgesNo,bool pointNo,bool doDir);

	// transforms a polygon in a "forme" structure, ie a set of contours, which can be holes (see ShapeUtils.h)
	// return NULL in case it's not possible
	void							ConvertToForme(Path* dest);
	// version to use when conversion was done with ConvertWithBackData(): will attempt to merge segment belonging to 
	// the same curve
	// nota: apparently the function doesn't like very small segments of arc
	void							ConvertToForme(Path* dest,int nbP,Path* *orig);
	
	// sweeping a digraph to produce a intersection-free polygon
	// return 0 if everything is ok and a return code otherwise (see LivarotDefs.h)
	// the input is the Shape "a"
	int               ConvertToShape(Shape* a,FillRule directed=fill_nonZero,bool invert=false); // directed=true <=> non-zero fill rule
																																									 // directed=false <=> even-odd fill rule
																					// invert=true: make as if you inverted all edges in the source
	int               Reoriente(Shape* a); // subcase of ConvertToShape: the input a is already intersection-free
	                                       // all that's missing are the correct directions of the edges
	                                       // Reoriented is equivalent to ConvertToShape(a,false,false) , but faster sicne
	                                       // it doesn't computes interections nor adjacencies
	void              ForceToPolygon(void); // force the Shape to believe it's a polygon (eulerian+intersection-free+no
	                                        // duplicate edges+no duplicate points)
	                                        // be careful when using this function

	// the coordinate rounding function
	static float             Round(float x) {return ldexpf(roundf(ldexpf(x,5)),-5);};
	// 2 miscannellous variations on it, to scale to and back the rounding grid
	static float             HalfRound(float x) {return ldexpf(x,-5);};
	static float             IHalfRound(float x) {return ldexpf(x,5);};

	// boolean operations on polygons (requests intersection-free poylygons)
	// boolean operation types are defined in LivarotDefs.h
	// same return code as ConvertToShape
	int               Booleen(Shape* a,Shape* b,BooleanOp mod);

	// rasterization routines
	// warning: rasterization accepts any graph, even if it's not a polygon -> self-intersections will give strange results
	void              BeginRaster(float &pos,int &curPt,float step=1.0); // start a new rasterization
	                               // BeginRaster sets pos to the topmost coordinate minus 1.0, so that pos is outside the
	                               // polygon; curPt is set to the index of the next point to consider in the scan, ie 0 at
	                               // the beginning
	                               // BeginRaster prepares the necessary structures, so you need a call to EndRaster to
	                               // deallocate them
	void              EndRaster(void); // clean up the Shape after a rasterization
	void              Scan(float &pos,int &curPt,float to,float step=1.0); // scan to vertical position "to"
	                                                        // this function can scan up or down
	void              Scan(float &pos,int &curPt,float to,FloatLigne* line,bool exact,float step=1.0); // scan (down only) to position "to"
											// and fill the structure line to reflect to coverage of the horizontal band between the
											// previous sweepline and the one at positin "to"
											// at the end of the function, the sweepline is moved to position "to"
	void              Scan(float &pos,int &curPt,float to,CoverageLigne* line,bool exact,float step=1.0);
//	void              Scan(float &pos,int &curPt,float to,AlphaLigne* line,bool exact,float step=1.0);
	void              Scan(float &pos,int &curPt,float to,FillRule directed,BitLigne* line,bool exact,float step=1.0);
	void              Scan(float &pos,int &curPt,float to,AlphaLigne* line,bool exact,float step=1.0);
	
	void              BeginQuickRaster(float &pos,int &curPt,float step=1.0);
	void              EndQuickRaster(void);
	void              QuickScan(float &pos,int &curPt,float to,bool sort=true,float step=1.0);
	void              QuickScan(float &pos,int &curPt,float to,FillRule directed,BitLigne* line,bool exact,float step=1.0);
	void              QuickScan(float &pos,int &curPt,float to,FloatLigne* line,bool exact,float step=1.0);
	void              QuickScan(float &pos,int &curPt,float to,CoverageLigne* line,bool exact,float step=1.0);
	void              QuickScan(float &pos,int &curPt,float to,AlphaLigne* line,bool exact,float step=1.0);

	
	// create a graph that is an offseted version of the graph "of"
	// the offset is dec, with joins between edges of type "join" (see LivarotDefs.h)
	// the result is NOT a polygon; you need a subsequent call to ConvertToShape to get a real polygon
	int               MakeOffset(Shape* of,float dec,JoinType join,float miter);

private:
		// coz' i'm lazy
		bool              SetFlag(int nFlag,bool nval);
	bool              GetFlag(int nFlag);
	
	// activation/deactivation of the temporary data arrays
	void              MakePointData(bool nVal);
	void              MakeEdgeData(bool nVal);
	void              MakeSweepSrcData(bool nVal);
	void              MakeSweepDestData(bool nVal);
	void              MakeRasterData(bool nVal);
	void              MakeQuickRasterData(bool nVal);

	bool              HasPointsData(void) {return (flags&has_points_data);};
	bool              HasEdgesData(void) {return (flags&has_edges_data);};
	bool              HasSweepSrcData(void) {return (flags&has_sweep_src_data);};
	bool              HasSweepDestData(void) {return (flags&has_sweep_dest_data);};
	bool              HasRasterData(void) {return (flags&has_raster_data);};
	bool              HasQuickRasterData(void) {return (flags&has_quick_raster_data);};
	bool              HasBackData(void) {return (flags&has_back_data);};
	bool              HasVoronoiData(void) {return (flags&has_voronoi_data);};
	
	void              SortPoints(int s,int e);
	void              SortPointsByOldInd(int s,int e);

	// fonctions annexes pour ConvertToShape et Booleen
	void              ResetSweep(void); // allocates sweep structures
	void              CleanupSweep(void); // deallocates them
//public:
private:
		typedef struct edge_list { // temporary array of edges for easier sorting
			int             no;
			bool            starting;
			float          x,y;
		} edge_list;
	void              SortEdgesList(edge_list* edges,int s,int e); // edge sorting function
	static int        CmpToVert(float ax,float ay,float bx,float by); // edge direction comparison function
	
	void              TesteIntersection(SweepTree* t,bool onLeft,bool onlyDiff); // test if there is an intersection
	bool              TesteIntersection(SweepTree* iL,SweepTree* iR,float &atx,float &aty,float &atL,float &atR,bool onlyDiff);
	bool              TesteIntersection(Shape* iL,Shape* iR,int ilb,int irb,float &atx,float &aty,float &atL,float &atR,bool onlyDiff);
	bool              TesteAdjacency(Shape* iL,int ilb,float atx,float aty,int nPt,bool push);
	int               PushIncidence(Shape* a,int cb,int pt,float theta);
	int               CreateIncidence(Shape* a,int cb,int pt);
	void              AssemblePoints(Shape* a);
	int               AssemblePoints(int st,int en);
	void              AssembleAretes(void);
	void              AddChgt(int lastPointNo,int lastChgtPt,Shape* &shapeHead,int &edgeHead,int type,Shape* lS,int lB,Shape* rS,int rB);
	void              CheckAdjacencies(int lastPointNo,int lastChgtPt,Shape *shapeHead,int edgeHead);
	void              CheckEdges(int lastPointNo,int lastChgtPt,Shape* a,Shape* b,BooleanOp mod);
	void              Avance(int lastPointNo,int lastChgtPt,Shape* iS,int iB,Shape* a,Shape* b,BooleanOp mod);
	void              DoEdgeTo(Shape* iS,int iB,int iTo,bool direct,bool sens);
	void              GetWindings(Shape* a,Shape* b=NULL,BooleanOp mod=bool_op_union,bool brutal=false);
	void              Validate(void);
	int               Winding(float px,float py);
	int               Winding(int nPt);
	void              SortPointsRounded(void);
	void              SortPointsRounded(int s,int e);
	static int        CmpIncidence(const void * p1, const void * p2) {
		incidenceData* d1=(incidenceData*)p1;
		incidenceData* d2=(incidenceData*)p2;
		if ( d1->theta == d2->theta ) return 0;
		return (( d1->theta < d2->theta )?-1:1);
	};
	static int CmpQuickRaster(const void * i1, const void * i2) {
		quick_raster_data* d1=(quick_raster_data*)i1;
		quick_raster_data* d2=(quick_raster_data*)i2;
		if ( d1->x < d2->x ) return -1;
		if ( d1->x > d2->x ) return 1;
		return 0;
	};

	void              AddContour(Path* dest,int nbP,Path* *orig,int startBord,int curBord);
	int               ReFormeLineTo(int bord,int curBord,Path *dest,Path* orig);
	int               ReFormeArcTo(int bord,int curBord,Path *dest,Path* orig);
	int               ReFormeCubicTo(int bord,int curBord,Path *dest,Path* orig);
	int               ReFormeBezierTo(int bord,int curBord,Path *dest,Path* orig);
	void							ReFormeBezierChunk(float px,float py,float nx,float ny,Path *dest,int inBezier,int nbInterm,Path* from,int p,float ts,float te);

		// annexes pour la rasterization
	void              CreateEdge(int no,float to,float step);
	void              DestroyEdge(int no,float to,float step);
	void              AvanceEdge(int no,float to,bool exact,float step);
	void              DestroyEdge(int no,float to,FloatLigne* line,float step);
	void              AvanceEdge(int no,float to,FloatLigne* line,bool exact,float step);
	void              DestroyEdge(int no,float to,CoverageLigne* line,float step);
	void              AvanceEdge(int no,float to,CoverageLigne* line,bool exact,float step);
	void              DestroyEdge(int no,float to,AlphaLigne* line,float step);
	void              AvanceEdge(int no,float to,AlphaLigne* line,bool exact,float step);
	void              DestroyEdge(int no,float to,BitLigne* line,float step);
	void              AvanceEdge(int no,float to,BitLigne* line,bool exact,float step);
};

#endif
