/*
 *  ShapeUtils.h
 *  nlivarot
 *
 *  Created by fred on Sun Jul 20 2003.
 *
 */

#ifndef my_shape_utils
#define my_shape_utils

#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
//#include <iostream.h>

#include "LivarotDefs.h"
#include "AVL.h"

class SweepTree;
class SweepEvent;
class Shape;
class FloatLigne;
class IntLigne;

// one contour: a list of points and a flag to tell if it's a hole
typedef struct boucle {
	bool     hole; // is a hole?
	int      nbPt; // number of points (x2)
	float    *pts; // coordinates

	void     Init(void) {hole=false;nbPt=0;pts=NULL;}; // init contour
	void     Kill(void) {if (pts) {free(pts);}nbPt=0;pts=NULL;}; // destroy the pts array
	void     AddPoint(float x, float y) { // add point to the contour
		int n=nbPt;
		nbPt+=2;
		pts=(float*)realloc(pts,nbPt*sizeof(float));
		pts[n]=x;
		pts[n+1]=y;
	};
	// debug
	void     Affiche(void) {if ( hole ) printf("hole ");for (int i=0;i<nbPt;i+=2) printf(" (%f ; %f)",pts[i],pts[i+1]);printf("\n");};
} boucle;

// one polygon: a set of contour
typedef struct forme {
	int      nbBcl; // number of contours
	boucle   *bcls; // contour list
	
	void     Init(void) {nbBcl=0;bcls=NULL;}; // init polygon
	// kill the polygon (kills the contours too)
	void     Kill(void) {if (bcls) {for (int i=0;i<nbBcl;i++) bcls[i].Kill();free(bcls);}nbBcl=0;bcls=NULL;};
	void     AddBoucle(boucle &iB) { // add one contour
		int n=nbBcl++;
		bcls=(boucle*)realloc(bcls,nbBcl*sizeof(boucle));
		bcls[n]=iB;
	};
	// debug
	void     Affiche(void) {for (int i=0;i<nbBcl;i++) bcls[i].Affiche();printf("\n");};
} forme;

// the structure to hold the intersections events encountered during the sweep
// it's an array of SweepEvent (not allocated with "new SweepEvent[n]" but with a malloc)
// there's a list of indices because it's a binary heap: inds[i] tell that events[inds[i]] has position i in the
// heap
// each SweepEvent has a field to store its index in the heap, too
typedef struct SweepEventQueue {
	int          nbEvt,maxEvt; // number of events currently in the heap, allocated size of the heap
	int*         inds;         // indices
	SweepEvent*  events;       // events
} SweepEventQueue;

// one intersection event
class SweepEvent {
public:
	SweepTree*     leftSweep;  // sweep element associated with the left edge of the intersection
	SweepTree*     rightSweep; // sweep element associated with the right edge 

	float          posx,posy; // coordinates of the intersection
	float          tl,tr;     // coordinates of the intersection on the left edge (tl) and on the right edge (tr)

	int            ind;  // index in the binary heap

	SweepEvent(void); // not used
	~SweepEvent(void); // not used

	// inits a SweepEvent structure
	void                   MakeNew(SweepTree* iLeft,SweepTree* iRight,float px,float py,float itl,float itr);
	// voids a SweepEvent structure
	void                   MakeDelete(void);

	// create the structure to store the binary heap
	static void            CreateQueue(SweepEventQueue &queue,int size);
	// destroy the structure
	static void            DestroyQueue(SweepEventQueue &queue);
	// add one intersection in the binary heap
	static SweepEvent*     AddInQueue(SweepTree* iLeft,SweepTree* iRight,float px,float py,float itl,float itr,SweepEventQueue &queue);
	// the calling SweepEvent removes itself from the binary heap
	void                   SupprFromQueue(SweepEventQueue &queue);
	// look for the topmost intersection in the heap
	static bool            PeekInQueue(SweepTree* &iLeft,SweepTree* &iRight,float &px,float &py,float &itl,float &itr,SweepEventQueue &queue);
	// extract the topmost intersection from the heap
	static bool            ExtractFromQueue(SweepTree* &iLeft,SweepTree* &iRight,float &px,float &py,float &itl,float &itr,SweepEventQueue &queue);

	// misc: change a SweepEvent structure's postion in the heap
	void                   Relocate(SweepEventQueue &queue,int to);
};

// the sweepline: a set of edges intersecting the current sweepline
// stored as an AVL tree
typedef struct SweepTreeList {
	int          nbTree,maxTree; // number of nodes in the tree, max number of nodes
	SweepTree*   trees; // the array of nodes
	SweepTree*   racine; // root of the tree
} SweepTreeList;

// one node in the AVL tree of edges
class SweepTree : public AVLTree {
public:
	SweepEvent*     leftEvt;  // intersection with the edge on the left (if any)
	SweepEvent*     rightEvt; // intersection with the edge on the right (if any)

	Shape*          src; // Shape from which the edge comes (when doing boolean operation on polygons, edges can come
	                     // from 2 different polygons)
	int             bord; // edge index in the Shape
	bool            sens;   // true= top->bottom; false= bottom->top
	int             startPoint; // point index in the result Shape associated with the upper end of the edge

	SweepTree(void);
	~SweepTree(void);

	void                 MakeNew(Shape* iSrc,int iBord,int iWeight,int iStartPoint);
	void                 ConvertTo(Shape* iSrc,int iBord,int iWeight,int iStartPoint);
	void                 MakeDelete(void);

	static void          CreateList(SweepTreeList &list,int size);
	static void          DestroyList(SweepTreeList &list);
	static SweepTree*    AddInList(Shape* iSrc,int iBord,int iWeight,int iStartPoint,SweepTreeList &list,Shape* iDst);

	int                  Find(float px,float py,SweepTree* newOne,SweepTree* &insertL,SweepTree* &insertR,bool sweepSens=true);
	int                  Find(float px,float py,SweepTree* &insertL,SweepTree* &insertR);
	void                 RemoveEvents(SweepEventQueue &queue);
	void                 RemoveEvent(SweepEventQueue &queue,bool onLeft);
	int                  Remove(SweepTreeList &list,SweepEventQueue &queue,bool rebalance=true);
	int                  Insert(SweepTreeList &list,SweepEventQueue &queue,Shape* iDst,int iAtPoint,bool rebalance=true,bool sweepSens=true);
	int                  InsertAt(SweepTreeList &list,SweepEventQueue &queue,Shape* iDst,SweepTree* insNode,int fromPt,bool rebalance=true,bool sweepSens=true);
	void                 SwapWithRight(SweepTreeList &list,SweepEventQueue &queue);

	void                 Avance(Shape* dst,int nPt,Shape* a,Shape* b);

	void                 Relocate(SweepTree* to);
};

#endif

