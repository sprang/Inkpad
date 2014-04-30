/*
 *  ShapeSweepUtils.cpp
 *  nlivarot
 *
 *  Created by fred on Wed Jun 18 2003.
 *
 */

#include "Shape.h"
#include "MyMath.h"

SweepEvent::SweepEvent()
{
	MakeNew(NULL,NULL,0,0,0,0);
}
SweepEvent::~SweepEvent(void)
{
	MakeDelete();
}

void
SweepEvent::MakeNew(SweepTree* iLeft,SweepTree* iRight,float px,float py,float itl,float itr)
{
	ind=-1;
	posx=px;
	posy=py;
	tl=itl;
	tr=itr;
	leftSweep=iLeft;
	rightSweep=iRight;
	leftSweep->rightEvt=this;
	rightSweep->leftEvt=this;
}
void
SweepEvent::MakeDelete(void)
{
	if ( leftSweep ) {
		if ( leftSweep->src->aretes[leftSweep->bord].st < leftSweep->src->aretes[leftSweep->bord].en ) {
			leftSweep->src->pData[leftSweep->src->aretes[leftSweep->bord].en].pending--;
		} else {
			leftSweep->src->pData[leftSweep->src->aretes[leftSweep->bord].st].pending--;
		}
		leftSweep->rightEvt=NULL;
	}
	if ( rightSweep ) {
		if ( rightSweep->src->aretes[rightSweep->bord].st < rightSweep->src->aretes[rightSweep->bord].en ) {
			rightSweep->src->pData[rightSweep->src->aretes[rightSweep->bord].en].pending--;
		} else {
			rightSweep->src->pData[rightSweep->src->aretes[rightSweep->bord].st].pending--;
		}
		rightSweep->leftEvt=NULL;
	}
	leftSweep=rightSweep=NULL;
}

void            SweepEvent::CreateQueue(SweepEventQueue &queue,int size)
{
	queue.nbEvt=0;
	queue.maxEvt=size;
	queue.events=(SweepEvent*)malloc(queue.maxEvt*sizeof(SweepEvent));
	queue.inds=(int*)malloc(queue.maxEvt*sizeof(int));
}
void            SweepEvent::DestroyQueue(SweepEventQueue &queue)
{
	if ( queue.events ) free(queue.events);
	if ( queue.inds ) free(queue.inds);
	queue.nbEvt=queue.maxEvt=0;
	queue.inds=NULL;
	queue.events=NULL;
}

SweepEvent*     SweepEvent::AddInQueue(SweepTree* iLeft,SweepTree* iRight,float px,float py,float itl,float itr,SweepEventQueue &queue)
{
	if ( queue.nbEvt >= queue.maxEvt ) return NULL;
	int  n=queue.nbEvt++;
	queue.events[n].MakeNew(iLeft,iRight,px,py,itl,itr);

	if ( iLeft->src->aretes[iLeft->bord].st < iLeft->src->aretes[iLeft->bord].en ) {
		iLeft->src->pData[iLeft->src->aretes[iLeft->bord].en].pending++;
	} else {
		iLeft->src->pData[iLeft->src->aretes[iLeft->bord].st].pending++;
	}
	if ( iRight->src->aretes[iRight->bord].st < iRight->src->aretes[iRight->bord].en ) {
		iRight->src->pData[iRight->src->aretes[iRight->bord].en].pending++;
	} else {
		iRight->src->pData[iRight->src->aretes[iRight->bord].st].pending++;
	}
	
	queue.events[n].ind=n;
	queue.inds[n]=n;
	
	int  curInd=n;
	while ( curInd > 0 ) {
		int  half=(curInd-1)/2;
		int  no=queue.inds[half];
		if ( py < queue.events[no].posy || ( py == queue.events[no].posy && px < queue.events[no].posx ) ) {
			queue.events[n].ind=half;
			queue.events[no].ind=curInd;
			queue.inds[half]=n;
			queue.inds[curInd]=no;
		} else {
			break;
		}
		curInd=half;
	}
	return queue.events+n;
}
void            SweepEvent::SupprFromQueue(SweepEventQueue &queue)
{
	if ( queue.nbEvt <= 1 ) {
		MakeDelete();
		queue.nbEvt=0;
		return;
	}
	int    n=ind;
	int    to=queue.inds[n];
	MakeDelete();
	queue.events[--queue.nbEvt].Relocate(queue,to);
	
	int    moveInd=queue.nbEvt;
	if ( moveInd == n ) return;
	to=queue.inds[moveInd];

	queue.events[to].ind=n;
	queue.inds[n]=to;
	
	int  curInd=n;
	float   px=queue.events[to].posx;
	float   py=queue.events[to].posy;
	bool    didClimb=false;
	while ( curInd > 0 ) {
		int  half=(curInd-1)/2;
		int  no=queue.inds[half];
		if ( py < queue.events[no].posy || ( py == queue.events[no].posy && px < queue.events[no].posx ) ) {
			queue.events[to].ind=half;
			queue.events[no].ind=curInd;
			queue.inds[half]=to;
			queue.inds[curInd]=no;
			didClimb=true;
		} else {
			break;
		}
		curInd=half;
	}
	if ( didClimb ) return;
	while ( 2*curInd+1 < queue.nbEvt ) {
		int   son1=2*curInd+1;
		int   son2=son1+1;
		int   no1=queue.inds[son1];
		int   no2=queue.inds[son2];
		if ( son2 < queue.nbEvt ) {
			if ( py > queue.events[no1].posy || ( py == queue.events[no1].posy && px > queue.events[no1].posx ) ) {
				if ( queue.events[no2].posy > queue.events[no1].posy || ( queue.events[no2].posy == queue.events[no1].posy && queue.events[no2].posx > queue.events[no1].posx ) ) {
					queue.events[to].ind=son1;
					queue.events[no1].ind=curInd;
					queue.inds[son1]=to;
					queue.inds[curInd]=no1;
					curInd=son1;
				} else {
					queue.events[to].ind=son2;
					queue.events[no2].ind=curInd;
					queue.inds[son2]=to;
					queue.inds[curInd]=no2;
					curInd=son2;
				}
			} else {
				if ( py > queue.events[no2].posy || ( py == queue.events[no2].posy && px > queue.events[no2].posx ) ) {
					queue.events[to].ind=son2;
					queue.events[no2].ind=curInd;
					queue.inds[son2]=to;
					queue.inds[curInd]=no2;
					curInd=son2;
				} else {
					break;
				}
			}
		} else {
			if ( py > queue.events[no1].posy || ( py == queue.events[no1].posy && px > queue.events[no1].posx ) ) {
				queue.events[to].ind=son1;
				queue.events[no1].ind=curInd;
				queue.inds[son1]=to;
				queue.inds[curInd]=no1;
			}
			break;
		}
	}
}
bool            SweepEvent::PeekInQueue(SweepTree* &iLeft,SweepTree* &iRight,float &px,float &py,float &itl,float &itr,SweepEventQueue &queue)
{
	if ( queue.nbEvt <= 0 ) return false;
	iLeft=queue.events[queue.inds[0]].leftSweep;
	iRight=queue.events[queue.inds[0]].rightSweep;
	px=queue.events[queue.inds[0]].posx;
	py=queue.events[queue.inds[0]].posy;
	itl=queue.events[queue.inds[0]].tl;
	itr=queue.events[queue.inds[0]].tr;
	return true;
}
bool            SweepEvent::ExtractFromQueue(SweepTree* &iLeft,SweepTree* &iRight,float &px,float &py,float &itl,float &itr,SweepEventQueue &queue)
{
	if ( queue.nbEvt <= 0 ) return false;
	iLeft=queue.events[queue.inds[0]].leftSweep;
	iRight=queue.events[queue.inds[0]].rightSweep;
	px=queue.events[queue.inds[0]].posx;
	py=queue.events[queue.inds[0]].posy;
	itl=queue.events[queue.inds[0]].tl;
	itr=queue.events[queue.inds[0]].tr;
	queue.events[queue.inds[0]].SupprFromQueue(queue);
	return true;
}
void            SweepEvent::Relocate(SweepEventQueue &queue,int to)
{
	if ( queue.inds[ind] == to ) return; // j'y suis deja
	
	queue.events[to].posx=posx;
	queue.events[to].posy=posy;
	queue.events[to].tl=tl;
	queue.events[to].tr=tr;
	queue.events[to].leftSweep=leftSweep;
	queue.events[to].rightSweep=rightSweep;
	leftSweep->rightEvt=queue.events+to;
	rightSweep->leftEvt=queue.events+to;
	queue.events[to].ind=ind;
	queue.inds[ind]=to;
}

/*
 *
 */

SweepTree::SweepTree(void)
{
	src=NULL;
	bord=-1;
	startPoint=-1;
	leftEvt=rightEvt=NULL;
	sens=true;
//	invDirLength=1;
}
SweepTree::~SweepTree(void)
{
	MakeDelete();
}
void
SweepTree::MakeNew(Shape* iSrc,int iBord,int iWeight,int iStartPoint)
{
AVLTree::MakeNew();
	ConvertTo(iSrc,iBord,iWeight,iStartPoint);
}
void
SweepTree::ConvertTo(Shape* iSrc,int iBord,int iWeight,int iStartPoint)
{
	src=iSrc;
	bord=iBord;
	leftEvt=rightEvt=NULL;
	startPoint=iStartPoint;
	if ( src->aretes[bord].st < src->aretes[bord].en ) {
		if ( iWeight >= 0 ) sens=true; else sens=false;
	} else {
		if ( iWeight >= 0 ) sens=false; else sens=true;
	}
//	invDirLength=src->eData[bord].isqlength;
//	invDirLength=1/sqrt(src->aretes[bord].dx*src->aretes[bord].dx+src->aretes[bord].dy*src->aretes[bord].dy);
}
void
SweepTree::MakeDelete(void)
{
	if ( leftEvt ) {
		leftEvt->rightSweep=NULL;
	}
	if ( rightEvt ) {
		rightEvt->leftSweep=NULL;
	}
	leftEvt=rightEvt=NULL;
AVLTree::MakeDelete();
}

void          SweepTree::CreateList(SweepTreeList &list,int size)
{
	list.nbTree=0;
	list.maxTree=size;
	list.trees=(SweepTree*)malloc(list.maxTree*sizeof(SweepTree));
	list.racine=NULL;
}
void          SweepTree::DestroyList(SweepTreeList &list)
{
	if ( list.trees ) free(list.trees);
	list.trees=NULL;
	list.nbTree=list.maxTree=0;
	list.racine=NULL;
}
SweepTree*    SweepTree::AddInList(Shape* iSrc,int iBord,int iWeight,int iStartPoint,SweepTreeList &list,Shape* iDst)
{
	if ( list.nbTree >= list.maxTree ) return NULL;
	int     n=list.nbTree++;
	list.trees[n].MakeNew(iSrc,iBord,iWeight,iStartPoint);

	return list.trees+n;
}
int           SweepTree::Find(float px,float py,SweepTree* newOne,SweepTree* &insertL,SweepTree* &insertR,bool sweepSens)
{
	vec2d    bOrig,bNorm;
	bOrig.x=src->pData[src->aretes[bord].st].rx;
	bOrig.y=src->pData[src->aretes[bord].st].ry;
	bNorm.x=src->eData[bord].rdx;
	bNorm.y=src->eData[bord].rdy;
	if ( src->aretes[bord].st > src->aretes[bord].en ) {
		bNorm.x=-bNorm.x;
		bNorm.y=-bNorm.y;
	}
	RotCCW(bNorm);
	
	vec2d    diff;
	diff.x=px-bOrig.x;
	diff.y=py-bOrig.y;
	
	double   y=0;
	//	if ( startPoint == newOne->startPoint ) {
 //		y=0;
 //	} else {
		y=Cross(bNorm,diff);
		//	}
	//	y*=invDirLength;
		if ( fabs(y) < 0.000001 ) {
			// prendre en compte les directions
			vec2d  nNorm;
			nNorm.x=newOne->src->eData[newOne->bord].rdx;
			nNorm.y=newOne->src->eData[newOne->bord].rdy;
			if ( newOne->src->aretes[newOne->bord].st > newOne->src->aretes[newOne->bord].en ) {
				nNorm.x=-nNorm.x;
				nNorm.y=-nNorm.y;
			}
			RotCCW(nNorm);
			
			if ( sweepSens ) {
				y=Dot(bNorm,nNorm);
			} else {
				y=Dot(nNorm,bNorm);
			}
			if ( y == 0 ) {
				y=Cross(bNorm,nNorm);
				if ( y == 0 ) {
					insertL=this;
					insertR=static_cast <SweepTree*> (rightElem);
					return found_exact;
				}
			}
		}
		if ( y < 0 ) {
			if ( sonL ) {
				return (static_cast <SweepTree*> (sonL))->Find(px,py,newOne,insertL,insertR,sweepSens);
			} else {
				insertR=this;
				insertL=static_cast <SweepTree*> (leftElem);
				if ( insertL ) {
					return found_between;
				} else {
					return found_on_left;
				}
			}
		} else {
			if ( sonR ) {
				return (static_cast <SweepTree*> (sonR))->Find(px,py,newOne,insertL,insertR,sweepSens);
			} else {
				insertL=this;
				insertR=static_cast <SweepTree*> (rightElem);
				if ( insertR ) {
					return found_between;
				} else {
					return found_on_right;
				}
			}
		}
		return not_found;
}
int           SweepTree::Find(float px,float py,SweepTree* &insertL,SweepTree* &insertR)
{
	vec2d    bOrig,bNorm;
	bOrig.x=src->pData[src->aretes[bord].st].rx;
	bOrig.y=src->pData[src->aretes[bord].st].ry;
	bNorm.x=src->eData[bord].rdx;
	bNorm.y=src->eData[bord].rdy;
	if ( src->aretes[bord].st > src->aretes[bord].en ) {
		bNorm.x=-bNorm.x;
		bNorm.y=-bNorm.y;
	}
	RotCCW(bNorm);
	
	vec2d    diff;
	diff.x=px-bOrig.x;
	diff.y=py-bOrig.y;
	
	double   y=0;
	y=Cross(bNorm,diff);
	if ( fabs(y) < 0.000001 ) {
		insertL=this;
		insertR=static_cast <SweepTree*> (rightElem);
		return found_exact;
	}
	if ( y < 0 ) {
		if ( sonL ) {
			return (static_cast <SweepTree*> (sonL))->Find(px,py,insertL,insertR);
		} else {
			insertR=this;
			insertL=static_cast <SweepTree*> (leftElem);
			if ( insertL ) {
				return found_between;
			} else {
				return found_on_left;
			}
		}
	} else {
		if ( sonR ) {
			return (static_cast <SweepTree*> (sonR))->Find(px,py,insertL,insertR);
		} else {
			insertL=this;
			insertR=static_cast <SweepTree*> (rightElem);
			if ( insertR ) {
				return found_between;
			} else {
				return found_on_right;
			}
		}
	}
	return not_found;
}
void          SweepTree::RemoveEvents(SweepEventQueue &queue)
{
	RemoveEvent(queue,true);
	RemoveEvent(queue,false);
}
void          SweepTree::RemoveEvent(SweepEventQueue &queue,bool onLeft)
{
	if ( onLeft ) {
		if ( leftEvt ) {
			leftEvt->SupprFromQueue(queue);
//			leftEvt->MakeDelete(); // fait dans SupprFromQueue
		}
		leftEvt=NULL;
	} else {
		if ( rightEvt ) {
			rightEvt->SupprFromQueue(queue);
//			rightEvt->MakeDelete(); // fait dans SupprFromQueue
		}
		rightEvt=NULL;
	}
}
int           SweepTree::Remove(SweepTreeList &list,SweepEventQueue &queue,bool rebalance)
{
	RemoveEvents(queue);
	AVLTree* tempR=static_cast <AVLTree*>(list.racine);
	int err=AVLTree::Remove(tempR,rebalance);
	list.racine=static_cast <SweepTree*> (tempR);
	MakeDelete();
	if ( list.nbTree <= 1 ) {
		list.nbTree=0;
		list.racine=NULL;
	} else {
		if ( list.racine == list.trees+(list.nbTree-1) ) list.racine=this;
		list.trees[--list.nbTree].Relocate(this);
	}
	return err;
}
int           SweepTree::Insert(SweepTreeList &list,SweepEventQueue &queue,Shape* iDst,int iAtPoint,bool rebalance,bool sweepSens)
{
	if ( list.racine == NULL ) {
		list.racine=this;
		return avl_no_err;
	}
	SweepTree*  insertL=NULL;
	SweepTree*  insertR=NULL;
	int insertion=list.racine->Find(iDst->pts[iAtPoint].x,iDst->pts[iAtPoint].y,this,insertL,insertR,sweepSens);
	if ( insertion == found_on_left ) {
	} else if ( insertion == found_on_right ) {
	} else if ( insertion == found_exact ) {
		if ( insertR ) insertR->RemoveEvent(queue,true);
		if ( insertL ) insertL->RemoveEvent(queue,false);
//		insertL->startPoint=startPoint;
	} else if ( insertion == found_between ) {
		insertR->RemoveEvent(queue,true);
		insertL->RemoveEvent(queue,false);
	}

	//	if ( insertL ) cout << insertL->bord; else cout << "-1";
 //	cout << "  <   ";
 //	cout << bord;
 //	cout << "  <   ";
 //	if ( insertR ) cout << insertR->bord; else cout << "-1";
 //	cout << endl;
	AVLTree* tempR=static_cast <AVLTree*>(list.racine);
	int err=AVLTree::Insert(tempR,insertion,static_cast <AVLTree*> (insertL),static_cast <AVLTree*> (insertR),rebalance);
	list.racine=static_cast <SweepTree*> (tempR);
	return err;
}
int           SweepTree::InsertAt(SweepTreeList &list,SweepEventQueue &queue,Shape* iDst,SweepTree* insNode,int fromPt,bool rebalance,bool sweepSens)
{
	if ( list.racine == NULL ) {
		list.racine=this;
		return avl_no_err;
	}

	vec2   fromP;
	fromP.x=src->pData[fromPt].rx;
	fromP.y=src->pData[fromPt].ry;
	vec2d  nNorm;
	nNorm.x=src->aretes[bord].dx;
	nNorm.y=src->aretes[bord].dy;
	if ( src->aretes[bord].st > src->aretes[bord].en ) {
		nNorm.x=-nNorm.x;
		nNorm.y=-nNorm.y;
	}
	if ( sweepSens == false ) {
		nNorm.x=-nNorm.x;
		nNorm.y=-nNorm.y;
	}

	vec2d    bNorm;
	bNorm.x=insNode->src->aretes[insNode->bord].dx;
	bNorm.y=insNode->src->aretes[insNode->bord].dy;
	if ( insNode->src->aretes[insNode->bord].st > insNode->src->aretes[insNode->bord].en ) {
		bNorm.x=-bNorm.x;
		bNorm.y=-bNorm.y;
	}

	SweepTree* insertL=NULL;
	SweepTree* insertR=NULL;
	double   ang=Dot(bNorm,nNorm);
	if ( ang == 0 ) {
		insertL=insNode;
		insertR=static_cast <SweepTree*> (insNode->rightElem);
	} else if ( ang > 0 ) {
		insertL=insNode;
		insertR=static_cast <SweepTree*> (insNode->rightElem);
		
		while ( insertL ) {
			if ( insertL->src == src ) {
				if ( insertL->src->aretes[insertL->bord].st != fromPt && insertL->src->aretes[insertL->bord].en != fromPt ) {
					break;
				}
			} else {
				int  ils=insertL->src->aretes[insertL->bord].st;
				int  ile=insertL->src->aretes[insertL->bord].en;
				if ( ( insertL->src->pData[ils].rx != fromP.x || insertL->src->pData[ils].ry != fromP.y ) &&
				 ( insertL->src->pData[ile].rx != fromP.x || insertL->src->pData[ile].ry != fromP.y ) ) {
					break;
				}
			}
			bNorm.x=insertL->src->aretes[insertL->bord].dx;
			bNorm.y=insertL->src->aretes[insertL->bord].dy;
			if ( insertL->src->aretes[insertL->bord].st > insertL->src->aretes[insertL->bord].en ) {
				bNorm.x=-bNorm.x;
				bNorm.y=-bNorm.y;
			}
			ang=Dot(bNorm,nNorm);
			if ( ang <= 0 ) {
				break;
			}
			insertR=insertL;
			insertL=static_cast <SweepTree*> (insertR->leftElem);
		}
	} else if ( ang < 0 ) {
		insertL=insNode;
		insertR=static_cast <SweepTree*> (insNode->rightElem);

		while ( insertR ) {
			if ( insertR->src == src ) {
				if ( insertR->src->aretes[insertR->bord].st != fromPt && insertR->src->aretes[insertR->bord].en != fromPt ) {
					break;
				}
			} else {
				int  ils=insertR->src->aretes[insertR->bord].st;
				int  ile=insertR->src->aretes[insertR->bord].en;
				if ( ( insertR->src->pData[ils].rx != fromP.x || insertR->src->pData[ils].ry != fromP.y ) &&
				 ( insertR->src->pData[ile].rx != fromP.x || insertR->src->pData[ile].ry != fromP.y ) ) {
					break;
				}
			}
			bNorm.x=insertR->src->aretes[insertR->bord].dx;
			bNorm.y=insertR->src->aretes[insertR->bord].dy;
			if ( insertR->src->aretes[insertR->bord].st > insertR->src->aretes[insertR->bord].en ) {
				bNorm.x=-bNorm.x;
				bNorm.y=-bNorm.y;
			}
			ang=Dot(bNorm,nNorm);
			if ( ang > 0 ) {
				break;
			}
			insertL=insertR;
			insertR=static_cast <SweepTree*> (insertL->rightElem);
		}
	}
		
	int insertion=found_between;
	if ( insertL == NULL ) insertion=found_on_left;
	if ( insertR == NULL ) insertion=found_on_right;
	if ( insertion == found_on_left ) {
	} else if ( insertion == found_on_right ) {
	} else if ( insertion == found_exact ) {
		if ( insertR ) insertR->RemoveEvent(queue,true);
		if ( insertL ) insertL->RemoveEvent(queue,false);
//		insertL->startPoint=startPoint;
	} else if ( insertion == found_between ) {
		insertR->RemoveEvent(queue,true);
		insertL->RemoveEvent(queue,false);
	}

	//	if ( insertL ) cout << insertL->bord; else cout << "-1";
 //	cout << "  <   ";
 //	cout << bord;
 //	cout << "  <   ";
 //	if ( insertR ) cout << insertR->bord; else cout << "-1";
 //	cout << endl;

	AVLTree* tempR=static_cast <AVLTree*>(list.racine);
	int err=AVLTree::Insert(tempR,insertion,static_cast <AVLTree*> (insertL),static_cast <AVLTree*> (insertR),rebalance);
	list.racine=static_cast <SweepTree*> (tempR);
	return err;
}
void          SweepTree::Relocate(SweepTree* to)
{
	if ( this == to ) return;
AVLTree::Relocate(to);
	to->src=src;
	to->bord=bord;
	to->sens=sens;
	to->leftEvt=leftEvt;
	to->rightEvt=rightEvt;
	to->startPoint=startPoint;
	if ( src->swsData ) src->swsData[bord].misc=to;
	if ( src->swrData ) src->swrData[bord].misc=to;
	if ( leftEvt ) leftEvt->rightSweep=to;
	if ( rightEvt ) rightEvt->leftSweep=to;
}
void          SweepTree::SwapWithRight(SweepTreeList &list,SweepEventQueue &queue)
{
	SweepTree* tL=this;
	SweepTree* tR=static_cast <SweepTree*> (rightElem);
	
	tL->src->swsData[tL->bord].misc=tR;
	tR->src->swsData[tR->bord].misc=tL;

	{Shape* swap=tL->src;tL->src=tR->src;tR->src=swap;}
	{int swap=tL->bord;tL->bord=tR->bord;tR->bord=swap;}
	{int swap=tL->startPoint;tL->startPoint=tR->startPoint;tR->startPoint=swap;}
//	{float swap=tL->invDirLength;tL->invDirLength=tR->invDirLength;tR->invDirLength=swap;}
	{bool swap=tL->sens;tL->sens=tR->sens;tR->sens=swap;}
}
void          SweepTree::Avance(Shape* dstPts,int curPoint,Shape* a,Shape* b)
{
	return;
/*	if ( curPoint != startPoint ) {
		int nb=-1;
		if ( sens ) {
//			nb=dstPts->AddEdge(startPoint,curPoint);
		} else {
//			nb=dstPts->AddEdge(curPoint,startPoint);
		}
		if ( nb >= 0 ) {
			dstPts->swsData[nb].misc=(void*)((src==b)?1:0);
			int   wp=waitingPoint;
			dstPts->eData[nb].firstLinkedPoint=waitingPoint;
			waitingPoint=-1;
			while ( wp >= 0 ) {
				dstPts->pData[wp].edgeOnLeft=nb;
				wp=dstPts->pData[wp].nextLinkedPoint;
			}
		}
		startPoint=curPoint;
	}*/
}

