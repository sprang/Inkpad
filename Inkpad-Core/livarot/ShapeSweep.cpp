/*
 *  ShapeSweep.cpp
 *  nlivarot
 *
 *  Created by fred on Thu Jun 19 2003.
 *
 */

#include "Shape.h"
#include "MyMath.h"


void              Shape::ResetSweep(void)
{
	MakePointData(true);
	MakeEdgeData(true);
	MakeSweepSrcData(true);
}
void              Shape::CleanupSweep(void)
{
	MakePointData(false);
	MakeEdgeData(false);
	MakeSweepSrcData(false);
}
void              Shape::ForceToPolygon(void)
{
	type=shape_polygon;
}
int               Shape::Reoriente(Shape* a)
{
	Reset(0,0);
	if ( a->nbPt <= 1 || a->nbAr <= 1 ) return 0;
	if ( a->Eulerian(true) == false ) return shape_input_err;

	nbPt=a->nbPt;
	if ( nbPt > maxPt ) {
		maxPt=nbPt;
		pts=(dg_point*)realloc(pts,maxPt*sizeof(dg_point));
		if ( HasPointsData() ) pData=(point_data*)realloc(pData,maxPt*sizeof(point_data));
	}
	memcpy(pts,a->pts,nbPt*sizeof(dg_point));

	nbAr=a->nbAr;
	if ( nbAr > maxAr ) {
		maxAr=nbAr;
		aretes=(dg_arete*)realloc(aretes,maxAr*sizeof(dg_arete));
		if ( HasEdgesData() ) eData=(edge_data*)realloc(eData,maxAr*sizeof(edge_data));
		if ( HasSweepSrcData() ) swsData=(sweep_src_data*)realloc(swsData,maxAr*sizeof(sweep_src_data));
		if ( HasSweepDestData() ) swdData=(sweep_dest_data*)realloc(swdData,maxAr*sizeof(sweep_dest_data));
		if ( HasRasterData() ) swrData=(raster_data*)realloc(swrData,maxAr*sizeof(raster_data));
	}
	memcpy(aretes,a->aretes,nbAr*sizeof(dg_arete));

	MakePointData(true);
	MakeEdgeData(true);
	MakeSweepDestData(true);

	for (int i=0;i<nbPt;i++) {
		pData[i].pending=0;
		pData[i].edgeOnLeft=-1;
		pData[i].nextLinkedPoint=-1;
		pData[i].rx=Round(pts[i].x);
		pData[i].ry=Round(pts[i].y);
		pts[i].x=pData[i].rx;
		pts[i].y=pData[i].ry;
	}
	for (int i=0;i<nbPt;i++) {
		pts[i].oldDegree=pts[i].dI+pts[i].dO;
	}
	for (int i=0;i<a->nbAr;i++) {
		eData[i].rdx=pData[aretes[i].en].rx-pData[aretes[i].st].rx;
		eData[i].rdy=pData[aretes[i].en].ry-pData[aretes[i].st].ry;
		eData[i].weight=1;
		aretes[i].dx=eData[i].rdx;
		aretes[i].dy=eData[i].rdy;
	}

	SortPointsRounded();
	
	SetFlag(need_edges_sorting,true);
	GetWindings(this,NULL,bool_op_union,true);

//	Plot(341,56,8,400,400,true,true,false,true);
	for (int i=0;i<nbAr;i++) {
		swdData[i].leW%=2;
		swdData[i].riW%=2;
		if ( swdData[i].leW < 0 ) swdData[i].leW=-swdData[i].leW;
		if ( swdData[i].riW < 0 ) swdData[i].riW=-swdData[i].riW;
		if ( swdData[i].leW > 0 && swdData[i].riW <= 0 ) {
			eData[i].weight=1;
		} else if ( swdData[i].leW <= 0 && swdData[i].riW > 0 ) {
			Inverse(i);
			eData[i].weight=1;
		} else {
			eData[i].weight=0;
			SubEdge(i);
			i--;
		}
	}

	MakePointData(false);
	MakeEdgeData(false);
	MakeSweepDestData(false);
	
	if ( Eulerian(true) == false ) {
//		printf( "pas euclidian2");
		nbPt=nbAr=0;
		return shape_euler_err;
	}
	
	type=shape_polygon;
	return 0;
}
int               Shape::ConvertToShape(Shape* a,FillRule directed,bool invert)
{
	Reset(0,0);
	if ( a->nbPt <= 1 || a->nbAr <= 1 ) return 0;
	if ( a->Eulerian(true) == false ) return shape_input_err;

	a->ResetSweep();

	if ( GetFlag(has_sweep_data) ) {
	} else {
SweepTree::CreateList(sTree,a->nbAr);
SweepEvent::CreateQueue(sEvts,a->nbAr);
		SetFlag(has_sweep_data,true);
	}
	MakePointData(true);
	MakeEdgeData(true);
	MakeSweepSrcData(true);
	MakeSweepDestData(true);
	if ( a->HasBackData() ) {
		MakeBackData(true);
	} else {
		MakeBackData(false);
	}
	
	for (int i=0;i<a->nbPt;i++) {
		a->pData[i].pending=0;
		a->pData[i].edgeOnLeft=-1;
		a->pData[i].nextLinkedPoint=-1;
		a->pData[i].rx=Round(a->pts[i].x);
		a->pData[i].ry=Round(a->pts[i].y);
	}
	for (int i=0;i<a->nbAr;i++) {
		a->eData[i].rdx=a->pData[a->aretes[i].en].rx-a->pData[a->aretes[i].st].rx;
		a->eData[i].rdy=a->pData[a->aretes[i].en].ry-a->pData[a->aretes[i].st].ry;
		a->eData[i].length=a->eData[i].rdx*a->eData[i].rdx+a->eData[i].rdy*a->eData[i].rdy;
		a->eData[i].ilength=1/a->eData[i].length;
		a->eData[i].sqlength=sqrt(a->eData[i].length);
		a->eData[i].isqlength=1/a->eData[i].sqlength;
		a->eData[i].siEd=a->eData[i].rdy*a->eData[i].isqlength;
		a->eData[i].coEd=a->eData[i].rdx*a->eData[i].isqlength;
		if ( a->eData[i].siEd < 0 ) {
			a->eData[i].siEd=-a->eData[i].siEd;
			a->eData[i].coEd=-a->eData[i].coEd;
		}
		
		a->swsData[i].misc=NULL;
		a->swsData[i].firstLinkedPoint=-1;
		a->swsData[i].stPt=a->swsData[i].enPt=-1;
		a->swsData[i].leftRnd=a->swsData[i].rightRnd=-1;
		a->swsData[i].nextSh=NULL;
		a->swsData[i].nextBo=-1;
		a->swsData[i].curPoint=-1;
		a->swsData[i].doneTo=-1;
	}
	
	a->SortPointsRounded();

//	a->Plot(200.0,200.0,2.0,400.0,400.0,true,true,true,true);

	chgts=NULL;
	nbChgt=maxChgt=0;
	
	float        lastChange=a->pData[0].ry-1.0;
	int          lastChgtPt=0;
	int          edgeHead=-1;
	Shape*       shapeHead=NULL;
	
	iData=NULL;
	nbInc=maxInc=0;
	
	int    curAPt=0;
	
	while ( curAPt < a->nbPt || sEvts.nbEvt > 0 ) {
/*		if ( nbPt > 0 && pts[nbPt-1].y >= 250.4 && pts[nbPt-1].y <= 250.6 ) {
			for (int i=0;i<sEvts.nbEvt;i++) {
				printf("%f %f %i %i\n",sEvts.events[i].posx,sEvts.events[i].posy,sEvts.events[i].leftSweep->bord,sEvts.events[i].rightSweep->bord);
			}
			//		cout << endl;
			if ( sTree.racine ) {
				SweepTree*  ct=static_cast <SweepTree*> (sTree.racine->Leftmost());
				while ( ct ) {
					printf("%i %i\n",ct->bord,ct->startPoint);
					ct=static_cast <SweepTree*> (ct->rightElem);
				}
			}
		}*/
//		cout << endl << endl;
		
		float         ptX,ptY;
		float         ptL,ptR;
		SweepTree*    intersL=NULL;
		SweepTree*    intersR=NULL;
		int           nPt=-1;
		Shape*        ptSh=NULL;
		bool          isIntersection=false;
		if ( SweepEvent::PeekInQueue(intersL,intersR,ptX,ptY,ptL,ptR,sEvts) ) {
			if ( a->pData[curAPt].pending > 0 || ( a->pData[curAPt].ry > ptY || ( a->pData[curAPt].ry == ptY && a->pData[curAPt].rx > ptX ) ) ) {
SweepEvent::ExtractFromQueue(intersL,intersR,ptX,ptY,ptL,ptR,sEvts);
				isIntersection=true;
			} else {
				nPt=curAPt++;
				ptSh=a;
				ptX=ptSh->pData[nPt].rx;
				ptY=ptSh->pData[nPt].ry;
				isIntersection=false;
			}
		} else {
			nPt=curAPt++;
			ptSh=a;
			ptX=ptSh->pData[nPt].rx;
			ptY=ptSh->pData[nPt].ry;
			isIntersection=false;
		}

		if ( isIntersection == false ) {
			if ( ptSh->pts[nPt].dI == 0 && ptSh->pts[nPt].dO == 0 ) continue;
		}
		
		float   rPtX=Round(ptX);
		float   rPtY=Round(ptY);
		int     lastPointNo=-1;
		lastPointNo=AddPoint(rPtX,rPtY);
		pData[lastPointNo].rx=rPtX;
		pData[lastPointNo].ry=rPtY;
		
		if ( rPtY > lastChange ) {
			int  lastI=AssemblePoints(lastChgtPt,lastPointNo);

			for (int i=lastChgtPt;i<lastI;i++) {
				if ( pData[i].askForWindingS ) {
					Shape* windS=pData[i].askForWindingS;
					int    windB=pData[i].askForWindingB;
					pData[i].nextLinkedPoint=windS->swsData[windB].firstLinkedPoint;
					windS->swsData[windB].firstLinkedPoint=i;
				}
			}
			
			Shape* curSh=shapeHead;
			int    curBo=edgeHead;
			while ( curSh ) {
				curSh->swsData[curBo].leftRnd=pData[curSh->swsData[curBo].leftRnd].newInd;
				curSh->swsData[curBo].rightRnd=pData[curSh->swsData[curBo].rightRnd].newInd;
				
				Shape* neSh=curSh->swsData[curBo].nextSh;
				curBo=curSh->swsData[curBo].nextBo;
				curSh=neSh;
			}

			for (int i=0;i<nbChgt;i++) {
				chgts[i].ptNo=pData[chgts[i].ptNo].newInd;
				if ( chgts[i].type == 0 ) {
					if ( chgts[i].src->aretes[chgts[i].bord].st < chgts[i].src->aretes[chgts[i].bord].en ) {
						chgts[i].src->swsData[chgts[i].bord].stPt=chgts[i].ptNo;
					} else {
						chgts[i].src->swsData[chgts[i].bord].enPt=chgts[i].ptNo;
					}
				} else if ( chgts[i].type == 1 ) {
					if ( chgts[i].src->aretes[chgts[i].bord].st > chgts[i].src->aretes[chgts[i].bord].en ) {
						chgts[i].src->swsData[chgts[i].bord].stPt=chgts[i].ptNo;
					} else {
						chgts[i].src->swsData[chgts[i].bord].enPt=chgts[i].ptNo;
					}
				}
			}

			CheckAdjacencies(lastI,lastChgtPt,shapeHead,edgeHead);

			CheckEdges(lastI,lastChgtPt,a,NULL,bool_op_union);

			if ( lastI < lastPointNo ) {
				pts[lastI]=pts[lastPointNo];
				pData[lastI]=pData[lastPointNo];
			}
			lastPointNo=lastI;
			nbPt=lastI+1;
			
			lastChgtPt=lastPointNo;
			lastChange=rPtY;
			nbChgt=0;
			edgeHead=-1;
			shapeHead=NULL;
		}

		
		if ( isIntersection ) {
//			printf("(%i %i [%i %i]) ",intersL->bord,intersR->bord,intersL->startPoint,intersR->startPoint);
			intersL->RemoveEvent(sEvts,true);
			intersR->RemoveEvent(sEvts,false);

			AddChgt(lastPointNo,lastChgtPt,shapeHead,edgeHead,2,intersL->src,intersL->bord,intersR->src,intersR->bord);
			
			intersL->SwapWithRight(sTree,sEvts);

			TesteIntersection(intersL,true,false);
			TesteIntersection(intersR,false,false);
		} else {
			int    cb;

			int    nbUp=0,nbDn=0;
			int    upNo=-1,dnNo=-1;
			cb=ptSh->pts[nPt].firstA;
			while ( cb >= 0 && cb < ptSh->nbAr ) {
				if ( ( ptSh->aretes[cb].st < ptSh->aretes[cb].en && nPt == ptSh->aretes[cb].en ) || ( ptSh->aretes[cb].st > ptSh->aretes[cb].en && nPt == ptSh->aretes[cb].st ) ) {
					upNo=cb;
					nbUp++;
				}
				if ( ( ptSh->aretes[cb].st > ptSh->aretes[cb].en && nPt == ptSh->aretes[cb].en ) || ( ptSh->aretes[cb].st < ptSh->aretes[cb].en && nPt == ptSh->aretes[cb].st ) ) {
					dnNo=cb;
					nbDn++;
				}
				cb=ptSh->NextAt(nPt,cb);
			}

			if ( nbDn <= 0 ) {
				upNo=-1;
			}
			if ( upNo >= 0 && (SweepTree*)ptSh->swsData[upNo].misc == NULL ) {
				upNo=-1;
			}

			bool doWinding=true;
			
			if ( nbUp > 0 ) {
				cb=ptSh->pts[nPt].firstA;
				while ( cb >= 0 && cb < ptSh->nbAr ) {
					if ( ( ptSh->aretes[cb].st < ptSh->aretes[cb].en && nPt == ptSh->aretes[cb].en ) || ( ptSh->aretes[cb].st > ptSh->aretes[cb].en && nPt == ptSh->aretes[cb].st ) ) {
						if ( cb != upNo ) {
							SweepTree* node=(SweepTree*)ptSh->swsData[cb].misc;
							if ( node == NULL ) {
							} else {
								AddChgt(lastPointNo,lastChgtPt,shapeHead,edgeHead,1,node->src,node->bord,NULL,-1);
								ptSh->swsData[cb].misc=NULL;

								int     onLeftB=-1,onRightB=-1;
								Shape*  onLeftS=NULL;
								Shape*  onRightS=NULL;
								if ( node->leftElem ) {
									onLeftB=(static_cast <SweepTree*> (node->leftElem))->bord;
									onLeftS=(static_cast <SweepTree*> (node->leftElem))->src;
								}
								if ( node->rightElem ) {
									onRightB=(static_cast <SweepTree*> (node->rightElem))->bord;
									onRightS=(static_cast <SweepTree*> (node->rightElem))->src;
								}

								node->Remove(sTree,sEvts,true);
								if ( onLeftS && onRightS ) {
									SweepTree* onLeft=(SweepTree*)onLeftS->swsData[onLeftB].misc;
									if ( onLeftS == ptSh && ( onLeftS->aretes[onLeftB].en == nPt || onLeftS->aretes[onLeftB].st == nPt ) ) {
									} else {
										if ( onRightS == ptSh && ( onRightS->aretes[onRightB].en == nPt || onRightS->aretes[onRightB].st == nPt ) ) {
										} else {
											TesteIntersection(onLeft,false,false);
										}
									}
								}
							}
						}
					}
					cb=ptSh->NextAt(nPt,cb);
				}
			}

			// traitement du "upNo devient dnNo"
			SweepTree* insertionNode=NULL;
			if ( dnNo >= 0 ) {
				if ( upNo >= 0 ) {
					SweepTree* node=(SweepTree*)ptSh->swsData[upNo].misc;
					
					AddChgt(lastPointNo,lastChgtPt,shapeHead,edgeHead,1,node->src,node->bord,NULL,-1);

					ptSh->swsData[upNo].misc=NULL;

					node->RemoveEvents(sEvts);
					node->ConvertTo(ptSh,dnNo,1,lastPointNo);
					ptSh->swsData[dnNo].misc=node;
					TesteIntersection(node,false,false);
					TesteIntersection(node,true,false);
					insertionNode=node;

					ptSh->swsData[dnNo].curPoint=lastPointNo;
					AddChgt(lastPointNo,lastChgtPt,shapeHead,edgeHead,0,node->src,node->bord,NULL,-1);
				} else {
					SweepTree* node=SweepTree::AddInList(ptSh,dnNo,1,lastPointNo,sTree,this);
					ptSh->swsData[dnNo].misc=node;
					node->Insert(sTree,sEvts,this,lastPointNo,true);
					if ( doWinding ) {
						SweepTree* myLeft=static_cast <SweepTree*> (node->leftElem);
						if ( myLeft ) {
							pData[lastPointNo].askForWindingS=myLeft->src;
							pData[lastPointNo].askForWindingB=myLeft->bord;
						} else {
							pData[lastPointNo].askForWindingB=-1;
						}
						doWinding=false;
					}
					TesteIntersection(node,false,false);
					TesteIntersection(node,true,false);
					insertionNode=node;

					ptSh->swsData[dnNo].curPoint=lastPointNo;
					AddChgt(lastPointNo,lastChgtPt,shapeHead,edgeHead,0,node->src,node->bord,NULL,-1);
				}
			}

			if ( nbDn > 1 ) { // si nbDn == 1 , alors dnNo a deja ete traite
				cb=ptSh->pts[nPt].firstA;
				while ( cb >= 0 && cb < ptSh->nbAr ) {
					if ( ( ptSh->aretes[cb].st > ptSh->aretes[cb].en && nPt == ptSh->aretes[cb].en ) || ( ptSh->aretes[cb].st < ptSh->aretes[cb].en && nPt == ptSh->aretes[cb].st ) ) {
						if ( cb != dnNo ) {
							SweepTree* node=SweepTree::AddInList(ptSh,cb,1,lastPointNo,sTree,this);
							ptSh->swsData[cb].misc=node;
							node->InsertAt(sTree,sEvts,this,insertionNode,nPt,true);
							if ( doWinding ) {
								SweepTree* myLeft=static_cast <SweepTree*> (node->leftElem);
								if ( myLeft ) {
									pData[lastPointNo].askForWindingS=myLeft->src;
									pData[lastPointNo].askForWindingB=myLeft->bord;
								} else {
									pData[lastPointNo].askForWindingB=-1;
								}
								doWinding=false;
							}
							TesteIntersection(node,false,false);
							TesteIntersection(node,true,false);

							ptSh->swsData[cb].curPoint=lastPointNo;
							AddChgt(lastPointNo,lastChgtPt,shapeHead,edgeHead,0,node->src,node->bord,NULL,-1);
						}
					}
					cb=ptSh->NextAt(nPt,cb);
				}
			}
		}
	}
	{
		int  lastI=AssemblePoints(lastChgtPt,nbPt);

		for (int i=lastChgtPt;i<lastI;i++) {
			if ( pData[i].askForWindingS ) {
				Shape* windS=pData[i].askForWindingS;
				int    windB=pData[i].askForWindingB;
				pData[i].nextLinkedPoint=windS->swsData[windB].firstLinkedPoint;
				windS->swsData[windB].firstLinkedPoint=i;
			}
		}
		
		Shape* curSh=shapeHead;
		int    curBo=edgeHead;
		while ( curSh ) {
			curSh->swsData[curBo].leftRnd=pData[curSh->swsData[curBo].leftRnd].newInd;
			curSh->swsData[curBo].rightRnd=pData[curSh->swsData[curBo].rightRnd].newInd;

			Shape* neSh=curSh->swsData[curBo].nextSh;
			curBo=curSh->swsData[curBo].nextBo;
			curSh=neSh;
		}

		for (int i=0;i<nbChgt;i++) {
			chgts[i].ptNo=pData[chgts[i].ptNo].newInd;
			if ( chgts[i].type == 0 ) {
				if ( chgts[i].src->aretes[chgts[i].bord].st < chgts[i].src->aretes[chgts[i].bord].en ) {
					chgts[i].src->swsData[chgts[i].bord].stPt=chgts[i].ptNo;
				} else {
					chgts[i].src->swsData[chgts[i].bord].enPt=chgts[i].ptNo;
				}
			} else if ( chgts[i].type == 1 ) {
				if ( chgts[i].src->aretes[chgts[i].bord].st > chgts[i].src->aretes[chgts[i].bord].en ) {
					chgts[i].src->swsData[chgts[i].bord].stPt=chgts[i].ptNo;
				} else {
					chgts[i].src->swsData[chgts[i].bord].enPt=chgts[i].ptNo;
				}
			}
		}

		CheckAdjacencies(lastI,lastChgtPt,shapeHead,edgeHead);

		CheckEdges(lastI,lastChgtPt,a,NULL,bool_op_union);

		nbPt=lastI;

		edgeHead=-1;
		shapeHead=NULL;
	}
	
	if ( chgts ) free(chgts);
	chgts=NULL;
	nbChgt=maxChgt=0;

//	Plot(98.0,112.0,8.0,400.0,400.0,true,true,true,true);
//	Plot(200.0,200.0,2.0,400.0,400.0,true,true,true,true);

	//	AssemblePoints(a);

//	GetAdjacencies(a);

//	MakeAretes(a);
	if ( iData ) free(iData);
	iData=NULL;
	nbInc=maxInc=0;
	
	AssembleAretes();

//	Plot(98.0,112.0,8.0,400.0,400.0,true,true,true,true);

	for (int i=0;i<nbPt;i++) {
		pts[i].oldDegree=pts[i].dI+pts[i].dO;
	}
	
//	Validate();

	SetFlag(need_edges_sorting,true);
	GetWindings(a);

//	Plot(98.0,112.0,8.0,400.0,400.0,true,true,true,true);
//	Plot(225.0,215.0,32.0,400.0,400.0,true,true,true,true);

	if ( directed == fill_positive) {
		if ( invert ) {
			for (int i=0;i<nbAr;i++) {
				if ( swdData[i].leW < 0 && swdData[i].riW >= 0 ) {
					eData[i].weight=1;
				} else if ( swdData[i].leW >= 0 && swdData[i].riW < 0 ) {
					Inverse(i);
					eData[i].weight=1;
				} else {
					eData[i].weight=0;
					SubEdge(i);
					i--;
				}
			}
		} else {
			for (int i=0;i<nbAr;i++) {
				if ( swdData[i].leW > 0 && swdData[i].riW <= 0 ) {
					eData[i].weight=1;
				} else if ( swdData[i].leW <= 0 && swdData[i].riW > 0 ) {
					Inverse(i);
					eData[i].weight=1;
				} else {
					eData[i].weight=0;
					SubEdge(i);
					i--;
				}
			}
		}
	} else if ( directed == fill_nonZero ) {
		if ( invert ) {
			for (int i=0;i<nbAr;i++) {
				if ( swdData[i].leW < 0 && swdData[i].riW == 0 ) {
					eData[i].weight=1;
				} else if ( swdData[i].leW > 0 && swdData[i].riW == 0 ) {
					eData[i].weight=1;
				} else if ( swdData[i].leW == 0 && swdData[i].riW < 0 ) {
					Inverse(i);
					eData[i].weight=1;
				} else if ( swdData[i].leW == 0 && swdData[i].riW > 0 ) {
					Inverse(i);
					eData[i].weight=1;
				} else {
					eData[i].weight=0;
					SubEdge(i);
					i--;
				}
			}
		} else {
			for (int i=0;i<nbAr;i++) {
				if ( swdData[i].leW > 0 && swdData[i].riW == 0 ) {
					eData[i].weight=1;
				} else if ( swdData[i].leW < 0 && swdData[i].riW == 0 ) {
					eData[i].weight=1;
				} else if ( swdData[i].leW == 0 && swdData[i].riW > 0 ) {
					Inverse(i);
					eData[i].weight=1;
				} else if ( swdData[i].leW == 0 && swdData[i].riW < 0 ) {
					Inverse(i);
					eData[i].weight=1;
				} else {
					eData[i].weight=0;
					SubEdge(i);
					i--;
				}
			}
		}
	} else if ( directed == fill_oddEven ) {
		for (int i=0;i<nbAr;i++) {
			swdData[i].leW%=2;
			swdData[i].riW%=2;
			if ( swdData[i].leW < 0 ) swdData[i].leW=-swdData[i].leW;
			if ( swdData[i].riW < 0 ) swdData[i].riW=-swdData[i].riW;
			if ( swdData[i].leW > 0 && swdData[i].riW <= 0 ) {
				eData[i].weight=1;
			} else if ( swdData[i].leW <= 0 && swdData[i].riW > 0 ) {
				Inverse(i);
				eData[i].weight=1;
			} else {
				eData[i].weight=0;
				SubEdge(i);
				i--;
			}
		}
	}

//	Plot(200.0,200.0,2.0,400.0,400.0,true,true,true,true);

	if ( GetFlag(has_sweep_data) ) {
SweepTree::DestroyList(sTree);
SweepEvent::DestroyQueue(sEvts);
		SetFlag(has_sweep_data,false);
	}
	MakePointData(false);
	MakeEdgeData(false);
	MakeSweepSrcData(false);
	MakeSweepDestData(false);
	a->CleanupSweep();
	
	if ( Eulerian(true) == false ) {
//		printf( "pas euclidian2");
		nbPt=nbAr=0;
		return shape_euler_err;
	}
	type=shape_polygon;
	return 0;
}

int               Shape::Booleen(Shape* a,Shape* b,BooleanOp mod)
{
	if ( a == b || a == NULL || b == NULL ) return shape_input_err;
	Reset(0,0);
	if ( a->nbPt <= 1 || a->nbAr <= 1 ) return 0;
	if ( b->nbPt <= 1 || b->nbAr <= 1 ) return 0;
	if ( a->type != shape_polygon ) return shape_input_err;
	if ( b->type != shape_polygon ) return shape_input_err;

	a->ResetSweep();
	b->ResetSweep();

	if ( GetFlag(has_sweep_data) ) {
	} else {
SweepTree::CreateList(sTree,a->nbAr+b->nbAr);
SweepEvent::CreateQueue(sEvts,a->nbAr+b->nbAr);
		SetFlag(has_sweep_data,true);
	}
	MakePointData(true);
	MakeEdgeData(true);
	MakeSweepSrcData(true);
	MakeSweepDestData(true);
	if ( a->HasBackData() && b->HasBackData() ) {
		MakeBackData(true);
	} else {
		MakeBackData(false);
	}

	for (int i=0;i<a->nbPt;i++) {
		a->pData[i].pending=0;
		a->pData[i].edgeOnLeft=-1;
		a->pData[i].nextLinkedPoint=-1;
		a->pData[i].rx=Round(a->pts[i].x);
		a->pData[i].ry=Round(a->pts[i].y);
	}
	for (int i=0;i<b->nbPt;i++) {
		b->pData[i].pending=0;
		b->pData[i].edgeOnLeft=-1;
		b->pData[i].nextLinkedPoint=-1;
		b->pData[i].rx=Round(b->pts[i].x);
		b->pData[i].ry=Round(b->pts[i].y);
	}
	for (int i=0;i<a->nbAr;i++) {
		a->eData[i].rdx=a->pData[a->aretes[i].en].rx-a->pData[a->aretes[i].st].rx;
		a->eData[i].rdy=a->pData[a->aretes[i].en].ry-a->pData[a->aretes[i].st].ry;
		a->eData[i].length=a->eData[i].rdx*a->eData[i].rdx+a->eData[i].rdy*a->eData[i].rdy;
		a->eData[i].ilength=1/a->eData[i].length;
		a->eData[i].sqlength=sqrt(a->eData[i].length);
		a->eData[i].isqlength=1/a->eData[i].sqlength;
		a->eData[i].siEd=a->eData[i].rdy*a->eData[i].isqlength;
		a->eData[i].coEd=a->eData[i].rdx*a->eData[i].isqlength;
		if ( a->eData[i].siEd < 0 ) {
			a->eData[i].siEd=-a->eData[i].siEd;
			a->eData[i].coEd=-a->eData[i].coEd;
		}
		
		a->swsData[i].misc=NULL;
		a->swsData[i].firstLinkedPoint=-1;
		a->swsData[i].stPt=a->swsData[i].enPt=-1;
		a->swsData[i].leftRnd=a->swsData[i].rightRnd=-1;
		a->swsData[i].nextSh=NULL;
		a->swsData[i].nextBo=-1;
		a->swsData[i].curPoint=-1;
		a->swsData[i].doneTo=-1;
	}
	for (int i=0;i<b->nbAr;i++) {
		b->eData[i].rdx=b->pData[b->aretes[i].en].rx-b->pData[b->aretes[i].st].rx;
		b->eData[i].rdy=b->pData[b->aretes[i].en].ry-b->pData[b->aretes[i].st].ry;
		b->eData[i].length=b->eData[i].rdx*b->eData[i].rdx+b->eData[i].rdy*b->eData[i].rdy;
		b->eData[i].ilength=1/b->eData[i].length;
		b->eData[i].sqlength=sqrt(b->eData[i].length);
		b->eData[i].isqlength=1/b->eData[i].sqlength;
		b->eData[i].siEd=b->eData[i].rdy*b->eData[i].isqlength;
		b->eData[i].coEd=b->eData[i].rdx*b->eData[i].isqlength;
		if ( b->eData[i].siEd < 0 ) {
			b->eData[i].siEd=-b->eData[i].siEd;
			b->eData[i].coEd=-b->eData[i].coEd;
		}
    
		b->swsData[i].misc=NULL;
		b->swsData[i].firstLinkedPoint=-1;
		b->swsData[i].stPt=b->swsData[i].enPt=-1;
		b->swsData[i].leftRnd=b->swsData[i].rightRnd=-1;
		b->swsData[i].nextSh=NULL;
		b->swsData[i].nextBo=-1;
		b->swsData[i].curPoint=-1;
		b->swsData[i].doneTo=-1;
	}

	a->SortPointsRounded();
	b->SortPointsRounded();

	chgts=NULL;
	nbChgt=maxChgt=0;

	float        lastChange=(a->pData[0].ry<b->pData[0].ry)?a->pData[0].ry-1.0:b->pData[0].ry-1.0;
	int          lastChgtPt=0;
	int          edgeHead=-1;
	Shape*       shapeHead=NULL;
	
	iData=NULL;
	nbInc=maxInc=0;

	int    curAPt=0;
	int    curBPt=0;
	
	while ( curAPt < a->nbPt || curBPt < b->nbPt || sEvts.nbEvt > 0 ) {
/*		for (int i=0;i<sEvts.nbEvt;i++) {
			printf("%f %f %i %i\n",sEvts.events[i].posx,sEvts.events[i].posy,sEvts.events[i].leftSweep->bord,sEvts.events[i].rightSweep->bord);
		}
		//		cout << endl;
		if ( sTree.racine ) {
			SweepTree*  ct=static_cast <SweepTree*> (sTree.racine->Leftmost());
			while ( ct ) {
				printf("%i %i [%i\n",ct->bord,ct->startPoint,(ct->src==a)?1:0);
				ct=static_cast <SweepTree*> (ct->rightElem);
			}
		}
		printf("\n");*/
		
		float         ptX,ptY;
		float         ptL,ptR;
		SweepTree*    intersL=NULL;
		SweepTree*    intersR=NULL;
		int           nPt=-1;
		Shape*        ptSh=NULL;
		bool          isIntersection=false;
		
		if ( SweepEvent::PeekInQueue(intersL,intersR,ptX,ptY,ptL,ptR,sEvts) ) {
			if ( curAPt < a->nbPt ) {
				if ( curBPt < b->nbPt ) {
					if ( a->pData[curAPt].ry < b->pData[curBPt].ry || ( a->pData[curAPt].ry == b->pData[curBPt].ry && a->pData[curAPt].rx < b->pData[curBPt].rx ) ) {
						if ( a->pData[curAPt].pending > 0 || ( a->pData[curAPt].ry > ptY || ( a->pData[curAPt].ry == ptY && a->pData[curAPt].rx > ptX ) ) ) {
SweepEvent::ExtractFromQueue(intersL,intersR,ptX,ptY,ptL,ptR,sEvts);
							isIntersection=true;
						} else {
							nPt=curAPt++;
							ptSh=a;
							ptX=ptSh->pData[nPt].rx;
							ptY=ptSh->pData[nPt].ry;
							isIntersection=false;
						}
					} else {
						if ( b->pData[curBPt].pending > 0 || ( b->pData[curBPt].ry > ptY || ( b->pData[curBPt].ry == ptY && b->pData[curBPt].rx > ptX ) ) ) {
SweepEvent::ExtractFromQueue(intersL,intersR,ptX,ptY,ptL,ptR,sEvts);
							isIntersection=true;
						} else {
							nPt=curBPt++;
							ptSh=b;
							ptX=ptSh->pData[nPt].rx;
							ptY=ptSh->pData[nPt].ry;
							isIntersection=false;
						}
					}
				} else {
					if ( a->pData[curAPt].pending > 0 || ( a->pData[curAPt].ry > ptY || ( a->pData[curAPt].ry == ptY && a->pData[curAPt].rx > ptX ) ) ) {
SweepEvent::ExtractFromQueue(intersL,intersR,ptX,ptY,ptL,ptR,sEvts);
						isIntersection=true;
					} else {
						nPt=curAPt++;
						ptSh=a;
						ptX=ptSh->pData[nPt].rx;
						ptY=ptSh->pData[nPt].ry;
						isIntersection=false;
					}
				}
			} else {
				if ( b->pData[curBPt].pending > 0 || ( b->pData[curBPt].ry > ptY || ( b->pData[curBPt].ry == ptY && b->pData[curBPt].rx > ptX ) ) ) {
SweepEvent::ExtractFromQueue(intersL,intersR,ptX,ptY,ptL,ptR,sEvts);
					isIntersection=true;
				} else {
					nPt=curBPt++;
					ptSh=b;
					ptX=ptSh->pData[nPt].rx;
					ptY=ptSh->pData[nPt].ry;
					isIntersection=false;
				}
			}
		} else {
			if ( curAPt < a->nbPt ) {
				if ( curBPt < b->nbPt ) {
					if ( a->pData[curAPt].ry < b->pData[curBPt].ry || ( a->pData[curAPt].ry == b->pData[curBPt].ry && a->pData[curAPt].rx < b->pData[curBPt].rx ) ) {
						nPt=curAPt++;
						ptSh=a;
					} else {
						nPt=curBPt++;
						ptSh=b;
					}
				} else {
					nPt=curAPt++;
					ptSh=a;
				}
			} else {
				nPt=curBPt++;
				ptSh=b;
			}
			ptX=ptSh->pData[nPt].rx;
			ptY=ptSh->pData[nPt].ry;
			isIntersection=false;
		}

		if ( isIntersection == false ) {
			if ( ptSh->pts[nPt].dI == 0 && ptSh->pts[nPt].dO == 0 ) continue;
		}

		float   rPtX=Round(ptX);
		float   rPtY=Round(ptY);
		int     lastPointNo=-1;
		lastPointNo=AddPoint(rPtX,rPtY);
		pData[lastPointNo].rx=rPtX;
		pData[lastPointNo].ry=rPtY;

		if ( rPtY > lastChange ) {
			int  lastI=AssemblePoints(lastChgtPt,lastPointNo);

			for (int i=lastChgtPt;i<lastI;i++) {
				if ( pData[i].askForWindingS ) {
					Shape* windS=pData[i].askForWindingS;
					int    windB=pData[i].askForWindingB;
					pData[i].nextLinkedPoint=windS->swsData[windB].firstLinkedPoint;
					windS->swsData[windB].firstLinkedPoint=i;
				}
			}

			Shape* curSh=shapeHead;
			int    curBo=edgeHead;
			while ( curSh ) {
				curSh->swsData[curBo].leftRnd=pData[curSh->swsData[curBo].leftRnd].newInd;
				curSh->swsData[curBo].rightRnd=pData[curSh->swsData[curBo].rightRnd].newInd;
				
				Shape* neSh=curSh->swsData[curBo].nextSh;
				curBo=curSh->swsData[curBo].nextBo;
				curSh=neSh;
			}

			for (int i=0;i<nbChgt;i++) {
				chgts[i].ptNo=pData[chgts[i].ptNo].newInd;
				if ( chgts[i].type == 0 ) {
					if ( chgts[i].src->aretes[chgts[i].bord].st < chgts[i].src->aretes[chgts[i].bord].en ) {
						chgts[i].src->swsData[chgts[i].bord].stPt=chgts[i].ptNo;
					} else {
						chgts[i].src->swsData[chgts[i].bord].enPt=chgts[i].ptNo;
					}
				} else if ( chgts[i].type == 1 ) {
					if ( chgts[i].src->aretes[chgts[i].bord].st > chgts[i].src->aretes[chgts[i].bord].en ) {
						chgts[i].src->swsData[chgts[i].bord].stPt=chgts[i].ptNo;
					} else {
						chgts[i].src->swsData[chgts[i].bord].enPt=chgts[i].ptNo;
					}
				}
			}

			CheckAdjacencies(lastI,lastChgtPt,shapeHead,edgeHead);

			CheckEdges(lastI,lastChgtPt,a,b,mod);

			if ( lastI < lastPointNo ) {
				pts[lastI]=pts[lastPointNo];
				pData[lastI]=pData[lastPointNo];
			}
			lastPointNo=lastI;
			nbPt=lastI+1;
			
			lastChgtPt=lastPointNo;
			lastChange=rPtY;
			nbChgt=0;
			edgeHead=-1;
			shapeHead=NULL;
		}

		
		if ( isIntersection ) {
			// les 2 events de part et d'autre de l'intersection
			// (celui de l'intersection a deja ete depile)
			intersL->RemoveEvent(sEvts,true);
			intersR->RemoveEvent(sEvts,false);

			AddChgt(lastPointNo,lastChgtPt,shapeHead,edgeHead,2,intersL->src,intersL->bord,intersR->src,intersR->bord);
			
			intersL->SwapWithRight(sTree,sEvts);

			TesteIntersection(intersL,true,true);
			TesteIntersection(intersR,false,true);
		} else {
			int    cb;
			
			int    nbUp=0,nbDn=0;
			int    upNo=-1,dnNo=-1;
			cb=ptSh->pts[nPt].firstA;
			while ( cb >= 0 && cb < ptSh->nbAr ) {
				if ( ( ptSh->aretes[cb].st < ptSh->aretes[cb].en && nPt == ptSh->aretes[cb].en ) || ( ptSh->aretes[cb].st > ptSh->aretes[cb].en && nPt == ptSh->aretes[cb].st ) ) {
					upNo=cb;
					nbUp++;
				}
				if ( ( ptSh->aretes[cb].st > ptSh->aretes[cb].en && nPt == ptSh->aretes[cb].en ) || ( ptSh->aretes[cb].st < ptSh->aretes[cb].en && nPt == ptSh->aretes[cb].st ) ) {
					dnNo=cb;
					nbDn++;
				}
				cb=ptSh->NextAt(nPt,cb);
			}

			if ( nbDn <= 0 ) {
				upNo=-1;
			}
			if ( upNo >= 0 && (SweepTree*)ptSh->swsData[upNo].misc == NULL ) {
				upNo=-1;
			}

//			upNo=-1;

			bool doWinding=true;
			
			if ( nbUp > 0 ) {
				cb=ptSh->pts[nPt].firstA;
				while ( cb >= 0 && cb < ptSh->nbAr ) {
					if ( ( ptSh->aretes[cb].st < ptSh->aretes[cb].en && nPt == ptSh->aretes[cb].en ) || ( ptSh->aretes[cb].st > ptSh->aretes[cb].en && nPt == ptSh->aretes[cb].st ) ) {
						if ( cb != upNo ) {
							SweepTree* node=(SweepTree*)ptSh->swsData[cb].misc;
							if ( node == NULL ) {
							} else {
								AddChgt(lastPointNo,lastChgtPt,shapeHead,edgeHead,1,node->src,node->bord,NULL,-1);
								ptSh->swsData[cb].misc=NULL;

								int     onLeftB=-1,onRightB=-1;
								Shape*  onLeftS=NULL;
								Shape*  onRightS=NULL;
								if ( node->leftElem ) {
									onLeftB=(static_cast <SweepTree*> (node->leftElem))->bord;
									onLeftS=(static_cast <SweepTree*> (node->leftElem))->src;
								}
								if ( node->rightElem ) {
									onRightB=(static_cast <SweepTree*> (node->rightElem))->bord;
									onRightS=(static_cast <SweepTree*> (node->rightElem))->src;
								}

								node->Remove(sTree,sEvts,true);
								if ( onLeftS && onRightS ) {
									SweepTree* onLeft=(SweepTree*)onLeftS->swsData[onLeftB].misc;
//									SweepTree* onRight=(SweepTree*)onRightS->swsData[onRightB].misc;
									if ( onLeftS == ptSh && ( onLeftS->aretes[onLeftB].en == nPt || onLeftS->aretes[onLeftB].st == nPt ) ) {
									} else {
										if ( onRightS == ptSh && ( onRightS->aretes[onRightB].en == nPt || onRightS->aretes[onRightB].st == nPt ) ) {
										} else {
											TesteIntersection(onLeft,false,true);
										}
									}
								}
							}
						}
					}
					cb=ptSh->NextAt(nPt,cb);
				}
			}

			// traitement du "upNo devient dnNo"
			SweepTree* insertionNode=NULL;
			if ( dnNo >= 0 ) {
				if ( upNo >= 0 ) {
					SweepTree* node=(SweepTree*)ptSh->swsData[upNo].misc;

					AddChgt(lastPointNo,lastChgtPt,shapeHead,edgeHead,1,node->src,node->bord,NULL,-1);

					ptSh->swsData[upNo].misc=NULL;

					node->RemoveEvents(sEvts);
					node->ConvertTo(ptSh,dnNo,1,lastPointNo);
					ptSh->swsData[dnNo].misc=node;
					TesteIntersection(node,false,true);
					TesteIntersection(node,true,true);
					insertionNode=node;

					ptSh->swsData[dnNo].curPoint=lastPointNo;

					AddChgt(lastPointNo,lastChgtPt,shapeHead,edgeHead,0,node->src,node->bord,NULL,-1);
				} else {
					SweepTree* node=SweepTree::AddInList(ptSh,dnNo,1,lastPointNo,sTree,this);
					ptSh->swsData[dnNo].misc=node;
					node->Insert(sTree,sEvts,this,lastPointNo,true);

					if ( doWinding ) {
						SweepTree* myLeft=static_cast <SweepTree*> (node->leftElem);
						if ( myLeft ) {
							pData[lastPointNo].askForWindingS=myLeft->src;
							pData[lastPointNo].askForWindingB=myLeft->bord;
						} else {
							pData[lastPointNo].askForWindingB=-1;
						}
						doWinding=false;
					}

					TesteIntersection(node,false,true);
					TesteIntersection(node,true,true);
					insertionNode=node;

					ptSh->swsData[dnNo].curPoint=lastPointNo;

					AddChgt(lastPointNo,lastChgtPt,shapeHead,edgeHead,0,node->src,node->bord,NULL,-1);
				}
			}

			if ( nbDn > 1 ) { // si nbDn == 1 , alors dnNo a deja ete traite
				cb=ptSh->pts[nPt].firstA;
				while ( cb >= 0 && cb < ptSh->nbAr ) {
					if ( ( ptSh->aretes[cb].st > ptSh->aretes[cb].en && nPt == ptSh->aretes[cb].en ) || ( ptSh->aretes[cb].st < ptSh->aretes[cb].en && nPt == ptSh->aretes[cb].st ) ) {
						if ( cb != dnNo ) {
							SweepTree* node=SweepTree::AddInList(ptSh,cb,1,lastPointNo,sTree,this);
							ptSh->swsData[cb].misc=node;
//							node->Insert(sTree,sEvts,this,lastPointNo,true);
							node->InsertAt(sTree,sEvts,this,insertionNode,nPt,true);

							if ( doWinding ) {
								SweepTree* myLeft=static_cast <SweepTree*> (node->leftElem);
								if ( myLeft ) {
									pData[lastPointNo].askForWindingS=myLeft->src;
									pData[lastPointNo].askForWindingB=myLeft->bord;
								} else {
									pData[lastPointNo].askForWindingB=-1;
								}
								doWinding=false;
							}
							
							TesteIntersection(node,false,true);
							TesteIntersection(node,true,true);

							ptSh->swsData[cb].curPoint=lastPointNo;

							AddChgt(lastPointNo,lastChgtPt,shapeHead,edgeHead,0,node->src,node->bord,NULL,-1);
						}
					}
					cb=ptSh->NextAt(nPt,cb);
				}
			}
		}
	}
	{
		int  lastI=AssemblePoints(lastChgtPt,nbPt);

		for (int i=lastChgtPt;i<lastI;i++) {
			if ( pData[i].askForWindingS ) {
				Shape* windS=pData[i].askForWindingS;
				int    windB=pData[i].askForWindingB;
				pData[i].nextLinkedPoint=windS->swsData[windB].firstLinkedPoint;
				windS->swsData[windB].firstLinkedPoint=i;
			}
		}
		
		Shape* curSh=shapeHead;
		int    curBo=edgeHead;
		while ( curSh ) {
			curSh->swsData[curBo].leftRnd=pData[curSh->swsData[curBo].leftRnd].newInd;
			curSh->swsData[curBo].rightRnd=pData[curSh->swsData[curBo].rightRnd].newInd;

			Shape* neSh=curSh->swsData[curBo].nextSh;
			curBo=curSh->swsData[curBo].nextBo;
			curSh=neSh;
		}

		for (int i=0;i<nbChgt;i++) {
			chgts[i].ptNo=pData[chgts[i].ptNo].newInd;
			if ( chgts[i].type == 0 ) {
				if ( chgts[i].src->aretes[chgts[i].bord].st < chgts[i].src->aretes[chgts[i].bord].en ) {
					chgts[i].src->swsData[chgts[i].bord].stPt=chgts[i].ptNo;
				} else {
					chgts[i].src->swsData[chgts[i].bord].enPt=chgts[i].ptNo;
				}
			} else if ( chgts[i].type == 1 ) {
				if ( chgts[i].src->aretes[chgts[i].bord].st > chgts[i].src->aretes[chgts[i].bord].en ) {
					chgts[i].src->swsData[chgts[i].bord].stPt=chgts[i].ptNo;
				} else {
					chgts[i].src->swsData[chgts[i].bord].enPt=chgts[i].ptNo;
				}
			}
		}

		CheckAdjacencies(lastI,lastChgtPt,shapeHead,edgeHead);

		CheckEdges(lastI,lastChgtPt,a,b,mod);

		nbPt=lastI;

		edgeHead=-1;
		shapeHead=NULL;
	}
	
	if ( chgts ) free(chgts);
	chgts=NULL;
	nbChgt=maxChgt=0;


//	MakeAretes(a,true);
/*	if ( mod == bool_op_diff || mod == bool_op_symdiff ) {
		MakeAretes(b,false);
	} else {
		MakeAretes(b,true);
	}*/
	
	if ( iData ) free(iData);
	iData=NULL;
	nbInc=maxInc=0;

//	Plot(190,70,6,400,400,true,false,true,true);

	AssembleAretes();

	for (int i=0;i<nbPt;i++) {
		pts[i].oldDegree=pts[i].dI+pts[i].dO;
	}

	SetFlag(need_edges_sorting,true);
	GetWindings(a,b,mod,false);

//	Plot(190,70,6,400,400,true,true,true,true);

	if ( mod == bool_op_symdiff ) {
		for (int i=0;i<nbAr;i++) {
			swdData[i].leW=swdData[i].leW%2;
			if ( swdData[i].leW < 0 ) swdData[i].leW=-swdData[i].leW;
			swdData[i].riW=swdData[i].riW;
			if ( swdData[i].riW < 0 ) swdData[i].riW=-swdData[i].riW;
			
			if ( swdData[i].leW > 0 && swdData[i].riW <= 0 ) {
				eData[i].weight=1;
			} else if ( swdData[i].leW <= 0 && swdData[i].riW > 0 ) {
				Inverse(i);
				eData[i].weight=1;
			} else {
				eData[i].weight=0;
				SubEdge(i);
				i--;
			}
		}
	} else if ( mod == bool_op_union || mod == bool_op_diff ) {
		for (int i=0;i<nbAr;i++) {
			if ( swdData[i].leW > 0 && swdData[i].riW <= 0 ) {
				eData[i].weight=1;
			} else if ( swdData[i].leW <= 0 && swdData[i].riW > 0 ) {
				Inverse(i);
				eData[i].weight=1;
			} else {
				eData[i].weight=0;
				SubEdge(i);
				i--;
			}
		}
	} else if ( mod == bool_op_inters ) {
		for (int i=0;i<nbAr;i++) {
			if ( swdData[i].leW > 1 && swdData[i].riW <= 1 ) {
				eData[i].weight=1;
			} else if ( swdData[i].leW <= 1 && swdData[i].riW > 1 ) {
				Inverse(i);
				eData[i].weight=1;
			} else {
				eData[i].weight=0;
				SubEdge(i);
				i--;
			}
		}
	} else {
		for (int i=0;i<nbAr;i++) {
			if ( swdData[i].leW > 0 && swdData[i].riW <= 0 ) {
				eData[i].weight=1;
			} else if ( swdData[i].leW <= 0 && swdData[i].riW > 0 ) {
				Inverse(i);
				eData[i].weight=1;
			} else {
				eData[i].weight=0;
				SubEdge(i);
				i--;
			}
		}
	}
	
	if ( GetFlag(has_sweep_data) ) {
SweepTree::DestroyList(sTree);
SweepEvent::DestroyQueue(sEvts);
		SetFlag(has_sweep_data,false);
	}
	MakePointData(false);
	MakeEdgeData(false);
	MakeSweepSrcData(false);
	MakeSweepDestData(false);
	a->CleanupSweep();
	b->CleanupSweep();
	
	if ( Eulerian(true) == false ) {
//		printf( "pas euclidian2");
		nbPt=nbAr=0;
		return shape_euler_err;
	}
	type=shape_polygon;
	return 0;
}

void            Shape::TesteIntersection(SweepTree* t,bool onLeft,bool onlyDiff)
{
	if ( onLeft ) {
		SweepTree* tL=static_cast <SweepTree*> (t->leftElem);
		if ( tL ) {
			float  atx,aty,atl,atr;
			if ( TesteIntersection(tL,t,atx,aty,atl,atr,onlyDiff) ) {
				SweepEvent::AddInQueue(tL,t,atx,aty,atl,atr,sEvts);
			}
		}
	} else {
		SweepTree* tR=static_cast <SweepTree*> (t->rightElem);
		if ( tR ) {
			float  atx,aty,atl,atr;
			if ( TesteIntersection(t,tR,atx,aty,atl,atr,onlyDiff) ) {
				SweepEvent::AddInQueue(t,tR,atx,aty,atl,atr,sEvts);
			}
		}
	}
}
bool            Shape::TesteIntersection(SweepTree* iL,SweepTree* iR,float &atx,float &aty,float &atL,float &atR,bool onlyDiff)
{
	int   lSt=iL->src->aretes[iL->bord].st,lEn=iL->src->aretes[iL->bord].en;
	int   rSt=iR->src->aretes[iR->bord].st,rEn=iR->src->aretes[iR->bord].en;
	vec2d  ldir,rdir;
	ldir.x=iL->src->eData[iL->bord].rdx;
	ldir.y=iL->src->eData[iL->bord].rdy;
	rdir.x=iR->src->eData[iR->bord].rdx;
	rdir.y=iR->src->eData[iR->bord].rdy;
	if ( lSt < lEn ) {} else {
		int swap=lSt;lSt=lEn;lEn=swap;
		ldir.x=-ldir.x;
		ldir.y=-ldir.y;
	}
	if ( rSt < rEn ) {} else {
		int swap=rSt;rSt=rEn;rEn=swap;
		rdir.x=-rdir.x;
		rdir.y=-rdir.y;
	}

	if ( iL->src->pData[lSt].rx < iL->src->pData[lEn].rx ) {
		if ( iR->src->pData[rSt].rx < iR->src->pData[rEn].rx ) {
			if ( iL->src->pData[lSt].rx > iR->src->pData[rEn].rx ) return false;
			if ( iL->src->pData[lEn].rx < iR->src->pData[rSt].rx ) return false;
		} else {
			if ( iL->src->pData[lSt].rx > iR->src->pData[rSt].rx ) return false;
			if ( iL->src->pData[lEn].rx < iR->src->pData[rEn].rx ) return false;
		}
	} else {
		if ( iR->src->pData[rSt].rx < iR->src->pData[rEn].rx ) {
			if ( iL->src->pData[lEn].rx > iR->src->pData[rEn].rx ) return false;
			if ( iL->src->pData[lSt].rx < iR->src->pData[rSt].rx ) return false;
		} else {
			if ( iL->src->pData[lEn].rx > iR->src->pData[rSt].rx ) return false;
			if ( iL->src->pData[lSt].rx < iR->src->pData[rEn].rx ) return false;
		}
	}

	double   ang=Dot(ldir,rdir);
//	ang*=iL->src->eData[iL->bord].isqlength;
//	ang*=iR->src->eData[iR->bord].isqlength;
	if ( ang <= 0 ) return false; // ca elimine les cas de colinearite

	// d'abord tester les bords qui partent d'un meme point
	if ( iL->src == iR->src && lSt == rSt ) {
		if ( iL->src == iR->src && lEn == rEn ) return false; // c'est juste un doublon
		atx=iL->src->pData[lSt].rx;
		aty=iL->src->pData[lSt].ry;
		atR=atL=-1;
		return true; // l'ordre est mauvais
	}
	if ( iL->src == iR->src && lEn == rEn ) return false; // rien a faire=ils vont terminer au meme endroit

	// tester si on est dans une intersection multiple
/*	if ( pts[iL->startPoint].x == pts[iR->startPoint].x && pts[iL->startPoint].y == pts[iR->startPoint].y ) {
		atx=pts[iL->startPoint].x;
		aty=pts[iL->startPoint].y;
		atL=atR=-1;
		return true; // mauvais ordre
	}*/

	if ( onlyDiff && iL->src == iR->src ) return false;

	// on reprend les vrais points
	lSt=iL->src->aretes[iL->bord].st;
	lEn=iL->src->aretes[iL->bord].en;
	rSt=iR->src->aretes[iR->bord].st;
	rEn=iR->src->aretes[iR->bord].en;
	
	// pre-test
	{
		vec2d   sDiff,eDiff;
		double  slDot,elDot;
		double  srDot,erDot;
		sDiff.x=iL->src->pData[lSt].rx-iR->src->pData[rSt].rx;
		sDiff.y=iL->src->pData[lSt].ry-iR->src->pData[rSt].ry;
		eDiff.x=iL->src->pData[lEn].rx-iR->src->pData[rSt].rx;
		eDiff.y=iL->src->pData[lEn].ry-iR->src->pData[rSt].ry;
		srDot=Dot(rdir,sDiff);
		erDot=Dot(rdir,eDiff);
		sDiff.x=iR->src->pData[rSt].rx-iL->src->pData[lSt].rx;
		sDiff.y=iR->src->pData[rSt].ry-iL->src->pData[lSt].ry;
		eDiff.x=iR->src->pData[rEn].rx-iL->src->pData[lSt].rx;
		eDiff.y=iR->src->pData[rEn].ry-iL->src->pData[lSt].ry;
		slDot=Dot(ldir,sDiff);
		elDot=Dot(ldir,eDiff);

		if ( ( srDot >= 0 && erDot >= 0 ) || ( srDot <= 0 && erDot <= 0 ) ) {
			if ( srDot == 0 ) {
				if ( lSt < lEn ) {
					atx=iL->src->pData[lSt].rx;
					aty=iL->src->pData[lSt].ry;
					atL=0;
					atR=slDot/(slDot-elDot);
					return true;
				} else {
					return false;
				}
			} else if ( erDot == 0 ) {
				if ( lSt > lEn ) {
					atx=iL->src->pData[lEn].rx;
					aty=iL->src->pData[lEn].ry;
					atL=1;
					atR=slDot/(slDot-elDot);
					return true;
				} else {
					return false;
				}
			}
			if ( srDot > 0 && erDot > 0 ) {
				if ( rEn < rSt ) {
					if ( srDot < erDot ) {
						if ( lSt < lEn ) {
							atx=iL->src->pData[lSt].rx;
							aty=iL->src->pData[lSt].ry;
							atL=0;
							atR=slDot/(slDot-elDot);
							return true;
						}
					} else {
						if ( lEn < lSt ) {
							atx=iL->src->pData[lEn].rx;
							aty=iL->src->pData[lEn].ry;
							atL=1;
							atR=slDot/(slDot-elDot);
							return true;
						}
					}
				}
			}
			if ( srDot < 0 && erDot < 0 ) {
				if ( rEn > rSt ) {
					if ( srDot > erDot ) {
						if ( lSt < lEn ) {
							atx=iL->src->pData[lSt].rx;
							aty=iL->src->pData[lSt].ry;
							atL=0;
							atR=slDot/(slDot-elDot);
							return true;
						}
					} else {
						if ( lEn < lSt ) {
							atx=iL->src->pData[lEn].rx;
							aty=iL->src->pData[lEn].ry;
							atL=1;
							atR=slDot/(slDot-elDot);
							return true;
						}
					}
				}
			}
			return false;
		}
		if ( ( slDot >= 0 && elDot >= 0 ) || ( slDot <= 0 && elDot <= 0 ) ) {
			if ( slDot == 0 ) {
				if ( rSt < rEn ) {
					atx=iR->src->pData[rSt].rx;
					aty=iR->src->pData[rSt].ry;
					atR=0;
					atL=srDot/(srDot-erDot);
					return true;
				} else {
					return false;
				}
			} else if ( elDot == 0 ) {
				if ( rSt > rEn ) {
					atx=iR->src->pData[rEn].rx;
					aty=iR->src->pData[rEn].ry;
					atR=1;
					atL=srDot/(srDot-erDot);
					return true;
				} else {
					return false;
				}
			}
			if ( slDot > 0 && elDot > 0 ) {
				if ( lEn > lSt ) {
					if ( slDot < elDot ) {
						if ( rSt < rEn ) {
							atx=iR->src->pData[rSt].rx;
							aty=iR->src->pData[rSt].ry;
							atR=0;
							atL=srDot/(srDot-erDot);
							return true;
						}
					} else {
						if ( rEn < rSt ) {
							atx=iR->src->pData[rEn].rx;
							aty=iR->src->pData[rEn].ry;
							atR=1;
							atL=srDot/(srDot-erDot);
							return true;
						}
					}
				}
			}
			if ( slDot < 0 && elDot < 0 ) {
				if ( lEn < lSt ) {
					if ( slDot > elDot ) {
						if ( rSt < rEn ) {
							atx=iR->src->pData[rSt].rx;
							aty=iR->src->pData[rSt].ry;
							atR=0;
							atL=srDot/(srDot-erDot);
							return true;
						}
					} else {
						if ( rEn < rSt ) {
							atx=iR->src->pData[rEn].rx;
							aty=iR->src->pData[rEn].ry;
							atR=1;
							atL=srDot/(srDot-erDot);
							return true;
						}
					}
				}
			}
			return false;
		}
		
/*		double  slb=slDot-elDot,srb=srDot-erDot;
		if ( slb < 0 ) slb=-slb;
		if ( srb < 0 ) srb=-srb;*/
		if ( iL->src->eData[iL->bord].siEd > iR->src->eData[iR->bord].siEd ) {
			atx=(slDot*iR->src->pData[rEn].rx-elDot*iR->src->pData[rSt].rx)/(slDot-elDot);
			aty=(slDot*iR->src->pData[rEn].ry-elDot*iR->src->pData[rSt].ry)/(slDot-elDot);
		} else {
			atx=(srDot*iL->src->pData[lEn].rx-erDot*iL->src->pData[lSt].rx)/(srDot-erDot);
			aty=(srDot*iL->src->pData[lEn].ry-erDot*iL->src->pData[lSt].ry)/(srDot-erDot);
		}
		atL=srDot/(srDot-erDot);
		atR=slDot/(slDot-elDot);
		return true;
	}
	
	return true;
}

int               Shape::PushIncidence(Shape* a,int cb,int pt,float theta)
{
	if ( theta < 0 || theta > 1 ) return -1;

	if ( nbInc >= maxInc ) {
		maxInc=2*nbInc+1;
		iData=(incidenceData*)realloc(iData,maxInc*sizeof(incidenceData));
	}
	int  n=nbInc++;
	iData[n].nextInc=a->swsData[cb].firstLinkedPoint;
	iData[n].pt=pt;
	iData[n].theta=theta;
	a->swsData[cb].firstLinkedPoint=n;
	return n;
}
int               Shape::CreateIncidence(Shape* a,int no,int nPt)
{
	vec2d  adir,diff;
	adir.x=a->eData[no].rdx;
	adir.y=a->eData[no].rdy;
	diff.x=pts[nPt].x-a->pData[a->aretes[no].st].rx;
	diff.y=pts[nPt].y-a->pData[a->aretes[no].st].ry;
	double  t=Cross(diff,adir);
	t*=a->eData[no].ilength;
	return PushIncidence(a,no,nPt,t);
}
int               Shape::Winding(int nPt)
{
	int   askTo=pData[nPt].askForWindingB;
	if ( askTo < 0 ) return 0;
	if ( aretes[askTo].st < aretes[askTo].en ) {
		return swdData[askTo].leW;
	} else {
		return swdData[askTo].riW;
	}
	return 0;
}
int               Shape::Winding(float px,float py)
{
	int lr=0,ll=0,rr=0;
	
	for (int i=0;i<nbAr;i++) {
		vec2d  adir,diff,ast,aen;
		adir.x=eData[i].rdx;
		adir.y=eData[i].rdy;

		ast.x=pData[aretes[i].st].rx;
		ast.y=pData[aretes[i].st].ry;
		aen.x=pData[aretes[i].en].rx;
		aen.y=pData[aretes[i].en].ry;

		int  nWeight=eData[i].weight;

		if ( ast.x < aen.x ) {
			if ( ast.x > px ) continue;
			if ( aen.x < px ) continue;
		} else {
			if ( ast.x < px ) continue;
			if ( aen.x > px ) continue;
		}
		if ( ast.x == px ) {
			if ( ast.y >= py ) continue;
			if ( aen.x == px ) continue;
			if ( aen.x < px ) ll+=nWeight; else rr-=nWeight;
			continue;
		}
		if ( aen.x == px ) {
			if ( aen.y >= py ) continue;
			if ( ast.x == px ) continue;
			if ( ast.x < px ) ll-=nWeight; else rr+=nWeight;
			continue;
		}
		
		if ( ast.y < aen.y ) {
			if ( ast.y >= py ) continue;
		} else {
			if ( aen.y >= py ) continue;
		}

		diff.x=px-ast.x;
		diff.y=py-ast.y;
		double cote=Dot(adir,diff);
		if ( cote == 0 ) continue;
		if ( cote < 0 ) {
			if ( ast.x > px ) lr+=nWeight;
		} else {
			if ( ast.x < px ) lr-=nWeight;
		}
	}
	return lr+(ll+rr)/2;
}
int              Shape::AssemblePoints(int st,int en)
{
	if ( en > st ) {
		for (int i=st;i<en;i++) pData[i].oldInd=i;
//		SortPoints(st,en-1);
		SortPointsByOldInd(st,en-1);
		for (int i=st;i<en;i++) pData[pData[i].oldInd].newInd=i;

		int   lastI=st;
		for (int i=st;i<en;i++) {
			pData[i].pending=lastI++;
			if ( i > st && pts[i-1].x == pts[i].x && pts[i-1].y == pts[i].y ) {
				pData[i].pending=pData[i-1].pending;
				if ( pData[pData[i].pending].askForWindingS == NULL ) {
					pData[pData[i].pending].askForWindingS=pData[i].askForWindingS;
					pData[pData[i].pending].askForWindingB=pData[i].askForWindingB;
				} else {
					if ( pData[pData[i].pending].askForWindingS == pData[i].askForWindingS && pData[pData[i].pending].askForWindingB == pData[i].askForWindingB ) {
						// meme bord, c bon
					} else {
						// meme point, mais pas le meme bord: ouille!
						// il faut prendre le bord le plus a gauche
						// en pratique, n'arrive que si 2 maxima sont dans la meme case -> le mauvais choix prend une arete incidente 
						// au bon choix
//						printf("doh");
					}
				}
				lastI--;
			} else {
				if ( i > pData[i].pending ) {
					pts[pData[i].pending].x=pts[i].x;
					pts[pData[i].pending].y=pts[i].y;
					pData[pData[i].pending].rx=pts[i].x;
					pData[pData[i].pending].ry=pts[i].y;
					pData[pData[i].pending].askForWindingS=pData[i].askForWindingS;
					pData[pData[i].pending].askForWindingB=pData[i].askForWindingB;
				}
			}
		}
		for (int i=st;i<en;i++) pData[i].newInd=pData[pData[i].newInd].pending;
		return lastI;
	}
	return en;
}
void              Shape::AssemblePoints(Shape* a)
{
	if ( nbPt > 0 ) {
		int lastI=AssemblePoints(0,nbPt);
		
		for (int i=0;i<a->nbAr;i++) {
			a->swsData[i].stPt=pData[a->swsData[i].stPt].newInd;
			a->swsData[i].enPt=pData[a->swsData[i].enPt].newInd;
		}
		for (int i=0;i<nbInc;i++) iData[i].pt=pData[iData[i].pt].newInd;

		nbPt=lastI;
	}
}
void              Shape::AssembleAretes(void)
{
	for (int i=0;i<nbPt;i++) {
		if ( pts[i].dI+pts[i].dO == 2 ) {
			int cb,cc;
			cb=pts[i].firstA;
			cc=pts[i].lastA;
			if ( ( aretes[cb].st == aretes[cc].st && aretes[cb].en == aretes[cc].en ) ||
				( aretes[cb].st == aretes[cc].en && aretes[cb].en == aretes[cc].en ) ) {
				if ( aretes[cb].st == aretes[cc].st ) {
					eData[cb].weight+=eData[cc].weight;
				} else {
					eData[cb].weight-=eData[cc].weight;
				}
				eData[cc].weight=0;

				if ( swsData[cc].firstLinkedPoint >= 0 ) {
					int  cp=swsData[cc].firstLinkedPoint;
					while ( cp >= 0 ) {
						pData[cp].askForWindingB=cb;
						cp=pData[cp].nextLinkedPoint;
					}
					if ( swsData[cb].firstLinkedPoint < 0 ) {
						swsData[cb].firstLinkedPoint=swsData[cc].firstLinkedPoint;
					} else {
						int ncp=swsData[cb].firstLinkedPoint;
						while ( pData[ncp].nextLinkedPoint >= 0 ) {
							ncp=pData[ncp].nextLinkedPoint;
						}
						pData[ncp].nextLinkedPoint=swsData[cc].firstLinkedPoint;
					}
				}

				DisconnectStart(cc);
				DisconnectEnd(cc);
				if ( nbAr > 1 ) {
					int  cp=swsData[nbAr-1].firstLinkedPoint;
					while ( cp >= 0 ) {
						pData[cp].askForWindingB=cc;
						cp=pData[cp].nextLinkedPoint;
					}
				}
				SwapEdges(cc,nbAr-1);
				if ( cb == nbAr-1 ) {
					cb=cc;
				}
				nbAr--;
			}
		} else {
			int cb;
			cb=pts[i].firstA;
			while ( cb >= 0 && cb < nbAr ) {
				int   other=Other(i,cb);
				int   cc;
				cc=pts[i].firstA;
				while ( cc >= 0 && cc < nbAr ) {
					int ncc=NextAt(i,cc);
					if ( cc != cb && Other(i,cc) == other ) {
						// doublon
						if ( aretes[cb].st == aretes[cc].st ) {
							eData[cb].weight+=eData[cc].weight;
						} else {
							eData[cb].weight-=eData[cc].weight;
						}
						eData[cc].weight=0;

						if ( swsData[cc].firstLinkedPoint >= 0 ) {
							int  cp=swsData[cc].firstLinkedPoint;
							while ( cp >= 0 ) {
								pData[cp].askForWindingB=cb;
								cp=pData[cp].nextLinkedPoint;
							}
							if ( swsData[cb].firstLinkedPoint < 0 ) {
								swsData[cb].firstLinkedPoint=swsData[cc].firstLinkedPoint;
							} else {
								int ncp=swsData[cb].firstLinkedPoint;
								while ( pData[ncp].nextLinkedPoint >= 0 ) {
									ncp=pData[ncp].nextLinkedPoint;
								}
								pData[ncp].nextLinkedPoint=swsData[cc].firstLinkedPoint;
							}
						}

						DisconnectStart(cc);
						DisconnectEnd(cc);
						if ( nbAr > 1 ) {
							int  cp=swsData[nbAr-1].firstLinkedPoint;
							while ( cp >= 0 ) {
								pData[cp].askForWindingB=cc;
								cp=pData[cp].nextLinkedPoint;
							}
						}
						SwapEdges(cc,nbAr-1);
						if ( cb == nbAr-1 ) {
							cb=cc;
						}
						if ( ncc == nbAr-1 ) {
							ncc=cc;
						}
						nbAr--;
					}
					cc=ncc;
				}
				cb=NextAt(i,cb);
			}
		}
	}

	for (int i=0;i<nbAr;i++) {
		if ( eData[i].weight == 0  ) {
//			SubEdge(i);
//			i--;
		} else {
			if ( eData[i].weight < 0 ) Inverse(i);
		}
	}
}
void         Shape::GetWindings(Shape* a,Shape* b,BooleanOp mod,bool brutal)
{
	// preparation du parcours
	for (int i=0;i<nbAr;i++) {
		swdData[i].misc=0;
		swdData[i].precParc=swdData[i].suivParc=-1;
	}

	// chainage
	SortEdges();

	int  searchInd=0;
	
	int  lastPtUsed=0;
	do {
		int   startBord=-1;
		int   outsideW=0;
		{
			int fi=0;
			for (fi=lastPtUsed;fi<nbPt;fi++) {
				if ( pts[fi].firstA >= 0 && swdData[pts[fi].firstA].misc == 0 ) break;
			}
			lastPtUsed=fi+1;
			if ( fi < nbPt ) {
				int      bestB=pts[fi].firstA;
				if ( bestB >= 0 ) {
					startBord=bestB;
					if ( fi == 0 ) {
						outsideW=0;
					} else {
						if ( brutal ) {
							outsideW=Winding(pts[fi].x,pts[fi].y);
						} else {
							outsideW=Winding(fi);
						}
					}
          if ( pts[fi].dI+pts[fi].dO == 1 ) {
            if ( fi == aretes[startBord].en ) {
              if ( eData[startBord].weight == 0 ) {
                // on se contente d'inverser
                Inverse(startBord);
              } else {
                // on passe le askForWinding (sinon ca va rester startBord)
                pData[aretes[startBord].st].askForWindingB=pData[aretes[startBord].en].askForWindingB;
              }
            }
          }
					if ( aretes[startBord].en == fi ) outsideW+=eData[startBord].weight;
				}
			}
		}
		if ( startBord >= 0 ) {
			// parcours en profondeur pour mettre les leF et riF a leurs valeurs
			swdData[startBord].misc=(void*)1;
			swdData[startBord].leW=outsideW;
			swdData[startBord].riW=outsideW-eData[startBord].weight;
//						printf("part de %d\n",startBord);
			int    curBord=startBord;
			bool   curDir=true;
			swdData[curBord].precParc=-1;
			swdData[curBord].suivParc=-1;
			do {
				int  cPt;
				if ( curDir ) cPt=aretes[curBord].en; else cPt=aretes[curBord].st;
				int  nb=curBord;
//								printf("de curBord= %d avec leF= %d et riF= %d  -> ",curBord,swdData[curBord].leW,swdData[curBord].riW);
				do {
					int nnb=-1;
					if ( aretes[nb].en == cPt ) {
						outsideW=swdData[nb].riW;
						nnb=CyclePrevAt(cPt,nb);
					} else{
						outsideW=swdData[nb].leW;
						nnb=CyclePrevAt(cPt,nb);
					}
					if ( nnb == nb ) {
						// cul-de-sac
						nb=-1;
						break;
					}
					nb=nnb;
				} while ( nb >= 0 && nb != curBord && swdData[nb].misc != 0 );
				if ( nb < 0 || nb == curBord ) {
					// retour en arriere
					int  oPt;
					if ( curDir ) oPt=aretes[curBord].st; else oPt=aretes[curBord].en;
					curBord=swdData[curBord].precParc;
//										printf("retour vers %d\n",curBord);
					if ( curBord < 0 ) break;
					if ( oPt == aretes[curBord].en ) curDir=true; else curDir=false;
				} else {
					swdData[nb].misc=(void*)1;
					swdData[nb].ind=searchInd++;
					if ( cPt == aretes[nb].st ) {
						swdData[nb].riW=outsideW;
						swdData[nb].leW=outsideW+eData[nb].weight;
					} else {
						swdData[nb].leW=outsideW;
						swdData[nb].riW=outsideW-eData[nb].weight;
					}
 					swdData[nb].precParc=curBord;
					swdData[curBord].suivParc=nb;
					curBord=nb;
	//									printf("suite %d\n",curBord);
					if ( cPt == aretes[nb].en ) curDir=false; else curDir=true;
				}
			} while ( 1 /*swdData[curBord].precParc >= 0*/ );
			// fin du cas non-oriente
		}
	} while ( lastPtUsed < nbPt );
//	fflush(stdout);
}
bool              Shape::TesteIntersection(Shape* ils,Shape* irs,int ilb,int irb,float &atx,float &aty,float &atL,float &atR,bool onlyDiff)
{
	int   lSt=ils->aretes[ilb].st,lEn=ils->aretes[ilb].en;
	int   rSt=irs->aretes[irb].st,rEn=irs->aretes[irb].en;
	if ( lSt == rSt || lSt == rEn ) {
		return false;
	}
	if ( lEn == rSt || lEn == rEn ) {
		return false;
	}
	
	vec2d  ldir,rdir;
	ldir.x=ils->eData[ilb].rdx;
	ldir.y=ils->eData[ilb].rdy;
	rdir.x=irs->eData[irb].rdx;
	rdir.y=irs->eData[irb].rdy;

	float  il=ils->pData[lSt].rx,it=ils->pData[lSt].ry,ir=ils->pData[lEn].rx,ib=ils->pData[lEn].ry;
	if ( il > ir ) {float swf=il;il=ir;ir=swf;}
	if ( it > ib ) {float swf=it;it=ib;ib=swf;}
	float  jl=irs->pData[rSt].rx,jt=irs->pData[rSt].ry,jr=irs->pData[rEn].rx,jb=irs->pData[rEn].ry;
	if ( jl > jr ) {float swf=jl;jl=jr;jr=swf;}
	if ( jt > jb ) {float swf=jt;jt=jb;jb=swf;}

	if ( il > jr || it > jb || ir < jl || ib < jt ) return false;

	// pre-test
	{
		vec2d   sDiff,eDiff;
		double  slDot,elDot;
		double  srDot,erDot;
		sDiff.x=ils->pData[lSt].rx-irs->pData[rSt].rx;
		sDiff.y=ils->pData[lSt].ry-irs->pData[rSt].ry;
		eDiff.x=ils->pData[lEn].rx-irs->pData[rSt].rx;
		eDiff.y=ils->pData[lEn].ry-irs->pData[rSt].ry;
		srDot=Dot(rdir,sDiff);
		erDot=Dot(rdir,eDiff);
		if ( ( srDot >= 0 && erDot >= 0 ) || ( srDot <= 0 && erDot <= 0 ) ) return false;

		sDiff.x=irs->pData[rSt].rx-ils->pData[lSt].rx;
		sDiff.y=irs->pData[rSt].ry-ils->pData[lSt].ry;
		eDiff.x=irs->pData[rEn].rx-ils->pData[lSt].rx;
		eDiff.y=irs->pData[rEn].ry-ils->pData[lSt].ry;
		slDot=Dot(ldir,sDiff);
		elDot=Dot(ldir,eDiff);
		if ( ( slDot >= 0 && elDot >= 0 ) || ( slDot <= 0 && elDot <= 0 ) ) return false;

		double  slb=slDot-elDot,srb=srDot-erDot;
		if ( slb < 0 ) slb=-slb;
		if ( srb < 0 ) srb=-srb;
		if ( slb > srb ) {
			atx=(slDot*irs->pData[rEn].rx-elDot*irs->pData[rSt].rx)/(slDot-elDot);
	 		aty=(slDot*irs->pData[rEn].ry-elDot*irs->pData[rSt].ry)/(slDot-elDot);
		} else {
			atx=(srDot*ils->pData[lEn].rx-erDot*ils->pData[lSt].rx)/(srDot-erDot);
			aty=(srDot*ils->pData[lEn].ry-erDot*ils->pData[lSt].ry)/(srDot-erDot);
		}
		atL=srDot/(srDot-erDot);
		atR=slDot/(slDot-elDot);
		return true;
	}

	// a mettre en double precision pour des resultats exacts
	vec2d  usvs;
	usvs.x=irs->pData[rSt].rx-ils->pData[lSt].rx;
	usvs.y=irs->pData[rSt].ry-ils->pData[lSt].ry;

	mat2d  m;
	m.xx=ldir.x;
	m.xy=ldir.y;
	m.yx=rdir.x;
	m.yy=rdir.y;

	double  det=m.xx*m.yy-m.xy*m.yx;

	double  tdet=det*ils->eData[ilb].isqlength*irs->eData[irb].isqlength;

	if ( tdet > -0.0001 && tdet < 0.0001 ) { // ces couillons de vecteurs sont colineaires
		vec2d   sDiff,eDiff;
		double  sDot,eDot;
		sDiff.x=ils->pData[lSt].rx-irs->pData[rSt].rx;
		sDiff.y=ils->pData[lSt].ry-irs->pData[rSt].ry;
		eDiff.x=ils->pData[lEn].rx-irs->pData[rSt].rx;
		eDiff.y=ils->pData[lEn].ry-irs->pData[rSt].ry;
		sDot=Dot(rdir,sDiff);
		eDot=Dot(rdir,eDiff);

		atx=(sDot*irs->pData[lEn].rx-eDot*irs->pData[lSt].rx)/(sDot-eDot);
		aty=(sDot*irs->pData[lEn].ry-eDot*irs->pData[lSt].ry)/(sDot-eDot);
		atL=sDot/(sDot-eDot);

		sDiff.x=irs->pData[rSt].rx-ils->pData[lSt].rx;
		sDiff.y=irs->pData[rSt].ry-ils->pData[lSt].ry;
		eDiff.x=irs->pData[rEn].rx-ils->pData[lSt].rx;
		eDiff.y=irs->pData[rEn].ry-ils->pData[lSt].ry;
		sDot=Dot(ldir,sDiff);
		eDot=Dot(ldir,eDiff);
	
		atR=sDot/(sDot-eDot);
		/*		vec2d   sDiff,eDiff;
		double  sDot,eDot;
		double  ths=0,the=1;
		vec2d   thst,then;
		int     sSens=0,eSens=0;
		thst.x=ils->pData[lSt].rx;
		thst.y=ils->pData[lSt].ry;
		then.x=ils->pData[lEn].rx;
		then.y=ils->pData[lEn].ry;
		
		sDiff.x=thst.x-irs->pData[rSt].rx;
		sDiff.y=thst.y-irs->pData[rSt].ry;
		eDiff.x=then.x-irs->pData[rSt].rx;
		eDiff.y=then.y-irs->pData[rSt].ry;
		sDot=Dot(rdir,sDiff);
		eDot=Dot(rdir,eDiff);
		sSens=(sDot > 0 )?1:-1;
		eSens=(eDot > 0 )?1:-1;
		
		while ( the-ths > 0.000000001 ) {
			double  nth=(ths+the)/2;
			vec2d   nthp;
			int     nSens;
			nthp.x=nth*ils->pData[lEn].rx+(1-nth)*ils->pData[lSt].rx;
			nthp.y=nth*ils->pData[lEn].ry+(1-nth)*ils->pData[lSt].ry;

			sDiff.x=nthp.x-irs->pData[rSt].rx;
			sDiff.y=nthp.y-irs->pData[rSt].ry;
			sDot=Dot(rdir,sDiff);
			nSens=(sDot > 0 )?1:-1;
			if ( nSens == 0 ) {thst=nthp;break;}
			if ( nSens > 0 && sSens > 0 ) {
				ths=nth;
				thst=nthp;
				sSens=nSens;
			} else {
				the=nth;
				then=nthp;
				eSens=nSens;
			}
		}

		atx=thst.x;
		aty=thst.y;

		sDiff.x=atx-ils->pData[lSt].rx;
		sDiff.y=aty-ils->pData[lSt].ry;
		double   atL=Cross(sDiff,ldir);
		atL*=ils->eData[ilb].ilength;
		sDiff.x=atx-irs->pData[rSt].rx;
		sDiff.y=aty-irs->pData[rSt].ry;
		double   atR=Cross(sDiff,rdir);
		atR*=irs->eData[irb].ilength;*/

		return true;
	}

	// plus de colinearite ni d'extremites en commun
	m.xy=-m.xy;
	m.yx=-m.yx;
	{double swap=m.xx;m.xx=m.yy;m.yy=swap;}

	atL=(m.xx*usvs.x+m.yx*usvs.y)/det;
	atR=-(m.xy*usvs.x+m.yy*usvs.y)/det;
	atx=ils->pData[lSt].rx+atL*ldir.x;
	aty=ils->pData[lSt].ry+atL*ldir.y;

/*	vec2d  diff;
	diff.x=atx-ils->pData[lSt].rx;
	diff.y=aty-ils->pData[lSt].ry;
	double   dtL=Cross(diff,ldir);
	dtL*=ils->eData[ilb].ilength;
	diff.x=atx-irs->pData[rSt].rx;
	diff.y=aty-irs->pData[rSt].ry;
	double   dtR=Cross(diff,rdir);
	dtR*=irs->eData[irb].ilength;

	atL=dtL;
	atR=dtR;*/
	
	return true;
}
bool              Shape::TesteAdjacency(Shape* a,int no,float atx,float aty,int nPt,bool push)
{
	if ( nPt == a->swsData[no].stPt || nPt == a->swsData[no].enPt ) return false;

	vec2d  adir,diff,ast,aen,diff1,diff2,diff3,diff4;

	ast.x=a->pData[a->aretes[no].st].rx;
	ast.y=a->pData[a->aretes[no].st].ry;
	aen.x=a->pData[a->aretes[no].en].rx;
	aen.y=a->pData[a->aretes[no].en].ry;

	adir.x=a->eData[no].rdx;
	adir.y=a->eData[no].rdy;

	double  sle=a->eData[no].length;
	double  ile=a->eData[no].ilength;

	diff.x=atx-ast.x;
	diff.y=aty-ast.y;

	double e=IHalfRound((Dot(adir,diff))*a->eData[no].isqlength);
	if ( -3 < e && e < 3 ) {
		double  rad=HalfRound(0.505);
		diff1.x=diff.x-rad;
		diff1.y=diff.y-rad;
		diff2.x=diff.x+rad;
		diff2.y=diff.y-rad;
		diff3.x=diff.x+rad;
		diff3.y=diff.y+rad;
		diff4.x=diff.x-rad;
		diff4.y=diff.y+rad;
		double  di1,di2;
		bool    adjacent=false;
		di1=Dot(adir,diff1);
		di2=Dot(adir,diff3);
		if ( ( di1 < 0 && di2 > 0 ) || ( di1 > 0 && di2 < 0 ) ) {
			adjacent=true;
		} else {
			di1=Dot(adir,diff2);
			di2=Dot(adir,diff4);
			if ( ( di1 < 0 && di2 > 0 ) || ( di1 > 0 && di2 < 0 ) ) {
				adjacent=true;
			}
		}
		if ( adjacent ) {
			double  t=Cross(diff,adir);
			if ( t > 0 && t < sle ) {
				if ( push ) {
					t*=ile;
					PushIncidence(a,no,nPt,t);
				}
				return true;
			}
		}
	}
/*	double e=Dot(adir,diff);
	if ( IHalfRound((e*a->eData[no].isqlength) < 2 ) {
		diff.x=e*adir.y*a->eData[no].ilength;
		diff.y=-e*adir.x*a->eData[no].ilength;
		diff.x=IHalfRound(diff.x);
		diff.y=IHalfRound(diff.y);
		if ( diff.x <= 0.7 && diff.x >= -0.7 && diff.y <= 0.7 && diff.y >= -0.7 ) {
			diff.x=atx-ast.x;
			diff.y=aty-ast.y;
			double  t=Cross(diff,adir);
			if ( t > 0 && t < sle ) {
				t*=ile;
				PushIncidence(a,no,nPt,t);
				return true;
			}
		}
	}*/
	return false;
}
void              Shape::CheckAdjacencies(int lastPointNo,int lastChgtPt,Shape *shapeHead,int edgeHead)
{
	for (int cCh=0;cCh<nbChgt;cCh++) {
		int   chLeN=chgts[cCh].ptNo;
		int   chRiN=chgts[cCh].ptNo;
		if ( chgts[cCh].src ) {
			Shape* lS=chgts[cCh].src;
			int    lB=chgts[cCh].bord;
			int   lftN=lS->swsData[lB].leftRnd;
			int   rgtN=lS->swsData[lB].rightRnd;
			if ( lftN < chLeN ) chLeN=lftN;
			if ( rgtN > chRiN ) chRiN=rgtN;
//			for (int n=lftN;n<=rgtN;n++) CreateIncidence(lS,lB,n);
			for (int n=lftN-1;n>=lastChgtPt;n--) {
				if ( TesteAdjacency(lS,lB,pts[n].x,pts[n].y,n,false) == false ) break;
				lS->swsData[lB].leftRnd=n;
			}
			for (int n=rgtN+1;n<lastPointNo;n++) {
				if ( TesteAdjacency(lS,lB,pts[n].x,pts[n].y,n,false) == false ) break;
				lS->swsData[lB].rightRnd=n;
			}
		}
		if ( chgts[cCh].osrc ) {
			Shape* rS=chgts[cCh].osrc;
			int    rB=chgts[cCh].obord;
			int   lftN=rS->swsData[rB].leftRnd;
			int   rgtN=rS->swsData[rB].rightRnd;
			if ( lftN < chLeN ) chLeN=lftN;
			if ( rgtN > chRiN ) chRiN=rgtN;
//			for (int n=lftN;n<=rgtN;n++) CreateIncidence(rS,rB,n);
			for (int n=lftN-1;n>=lastChgtPt;n--) {
				if ( TesteAdjacency(rS,rB,pts[n].x,pts[n].y,n,false) == false ) break;
				rS->swsData[rB].leftRnd=n;
			}
			for (int n=rgtN+1;n<lastPointNo;n++) {
				if ( TesteAdjacency(rS,rB,pts[n].x,pts[n].y,n,false) == false ) break;
				rS->swsData[rB].rightRnd=n;
			}
		}
		if ( chgts[cCh].lSrc ) {
			if ( chgts[cCh].lSrc->swsData[chgts[cCh].lBrd].leftRnd < lastChgtPt ) {
				Shape* nSrc=chgts[cCh].lSrc;
				int    nBrd=chgts[cCh].lBrd/*,nNo=chgts[cCh].ptNo*/;
				bool hit;
				
				do {
					hit=false;
					for (int n=chRiN;n>=chLeN;n--) {
						if ( TesteAdjacency(nSrc,nBrd,pts[n].x,pts[n].y,n,false) ) {
							if ( nSrc->swsData[nBrd].leftRnd < lastChgtPt ) {
								nSrc->swsData[nBrd].leftRnd=n;
								nSrc->swsData[nBrd].rightRnd=n;
							} else {
								if ( n < nSrc->swsData[nBrd].leftRnd ) nSrc->swsData[nBrd].leftRnd=n;
								if ( n > nSrc->swsData[nBrd].rightRnd ) nSrc->swsData[nBrd].rightRnd=n;
							}
							hit=true;
						}
					}
					for (int n=chLeN-1;n>=lastChgtPt;n--) {
						if ( TesteAdjacency(nSrc,nBrd,pts[n].x,pts[n].y,n,false) == false ) break;
						if ( nSrc->swsData[nBrd].leftRnd < lastChgtPt ) {
							nSrc->swsData[nBrd].leftRnd=n;
							nSrc->swsData[nBrd].rightRnd=n;
						} else { 
							if ( n < nSrc->swsData[nBrd].leftRnd ) nSrc->swsData[nBrd].leftRnd=n;
							if ( n > nSrc->swsData[nBrd].rightRnd ) nSrc->swsData[nBrd].rightRnd=n;
						}
						hit=true;
					}
					if ( hit ) {
						SweepTree* node=static_cast <SweepTree*> (nSrc->swsData[nBrd].misc);
						if ( node == NULL ) break;
						node=static_cast <SweepTree*> (node->leftElem);
						if ( node == NULL ) break;
						nSrc=node->src;
						nBrd=node->bord;
						if ( nSrc->swsData[nBrd].leftRnd >= lastChgtPt ) break;
					}
				} while ( hit );
				
			}
		}
		if ( chgts[cCh].rSrc ) {
			if ( chgts[cCh].rSrc->swsData[chgts[cCh].rBrd].leftRnd < lastChgtPt ) {
				Shape* nSrc=chgts[cCh].rSrc;
				int    nBrd=chgts[cCh].rBrd/*,nNo=chgts[cCh].ptNo*/;
				bool hit;
				do {
					hit=false;
					for (int n=chLeN;n<=chRiN;n++) {
						if ( TesteAdjacency(nSrc,nBrd,pts[n].x,pts[n].y,n,false) ) {
							if ( nSrc->swsData[nBrd].leftRnd < lastChgtPt ) {
								nSrc->swsData[nBrd].leftRnd=n;
								nSrc->swsData[nBrd].rightRnd=n;
							} else {
								if ( n < nSrc->swsData[nBrd].leftRnd ) nSrc->swsData[nBrd].leftRnd=n;
								if ( n > nSrc->swsData[nBrd].rightRnd ) nSrc->swsData[nBrd].rightRnd=n;
							}
							hit=true;
						}
					}
					for (int n=chRiN+1;n<lastPointNo;n++) {
						if ( TesteAdjacency(nSrc,nBrd,pts[n].x,pts[n].y,n,false) == false ) break;
						if ( nSrc->swsData[nBrd].leftRnd < lastChgtPt ) {
							nSrc->swsData[nBrd].leftRnd=n;
							nSrc->swsData[nBrd].rightRnd=n;
						} else {
							if ( n < nSrc->swsData[nBrd].leftRnd ) nSrc->swsData[nBrd].leftRnd=n;
							if ( n > nSrc->swsData[nBrd].rightRnd ) nSrc->swsData[nBrd].rightRnd=n;
						}
						hit=true;
					}
					if ( hit ) {
						SweepTree* node=static_cast <SweepTree*> (nSrc->swsData[nBrd].misc);
						if ( node == NULL ) break;
						node=static_cast <SweepTree*> (node->rightElem);
						if ( node == NULL ) break;
						nSrc=node->src;
						nBrd=node->bord;
						if ( nSrc->swsData[nBrd].leftRnd >= lastChgtPt ) break;
					}
				} while ( hit );
			}
		}
	}
}

void              Shape::AddChgt(int lastPointNo,int lastChgtPt,Shape* &shapeHead,int &edgeHead,int type,Shape* lS,int lB,Shape* rS,int rB)
{
	if ( nbChgt >= maxChgt ) {
		maxChgt=2*nbChgt+1;
		chgts=(sTreeChange*)realloc(chgts,maxChgt*sizeof(sTreeChange));
	}
	int  nCh=nbChgt++;
	chgts[nCh].ptNo=lastPointNo;
	chgts[nCh].type=type;
	chgts[nCh].src=lS;
	chgts[nCh].bord=lB;
	chgts[nCh].osrc=rS;
	chgts[nCh].obord=rB;
	if ( lS ) {
		SweepTree* lE=static_cast <SweepTree*> (lS->swsData[lB].misc);
		if ( lE && lE->leftElem ) {
			SweepTree* llE=static_cast <SweepTree*> (lE->leftElem);
			chgts[nCh].lSrc=llE->src;
			chgts[nCh].lBrd=llE->bord;
		} else {
			chgts[nCh].lSrc=NULL;
			chgts[nCh].lBrd=-1;
		}

		if ( lS->swsData[lB].leftRnd < lastChgtPt ) {
			lS->swsData[lB].leftRnd=lastPointNo;
			lS->swsData[lB].nextSh=shapeHead;
			lS->swsData[lB].nextBo=edgeHead;
			edgeHead=lB;
			shapeHead=lS;
		} else {
			int  old=lS->swsData[lB].leftRnd;
			if ( pts[old].x > pts[lastPointNo].x ) lS->swsData[lB].leftRnd=lastPointNo;
		}
		if ( lS->swsData[lB].rightRnd < lastChgtPt ) {
			lS->swsData[lB].rightRnd=lastPointNo;
		} else {
			int  old=lS->swsData[lB].rightRnd;
			if ( pts[old].x < pts[lastPointNo].x ) lS->swsData[lB].rightRnd=lastPointNo;
		}
	}

	if ( rS ) {
		SweepTree* rE=static_cast <SweepTree*> (rS->swsData[rB].misc);
		if ( rE->rightElem ) {
			SweepTree* rrE=static_cast <SweepTree*> (rE->rightElem);
			chgts[nCh].rSrc=rrE->src;
			chgts[nCh].rBrd=rrE->bord;
		} else {
			chgts[nCh].rSrc=NULL;
			chgts[nCh].rBrd=-1;
		}

		if ( rS->swsData[rB].leftRnd < lastChgtPt ) {
			rS->swsData[rB].leftRnd=lastPointNo;
			rS->swsData[rB].nextSh=shapeHead;
			rS->swsData[rB].nextBo=edgeHead;
			edgeHead=rB;
			shapeHead=rS;
		} else {
			int  old=rS->swsData[rB].leftRnd;
			if ( pts[old].x > pts[lastPointNo].x ) rS->swsData[rB].leftRnd=lastPointNo;
		}
		if ( rS->swsData[rB].rightRnd < lastChgtPt ) {
			rS->swsData[rB].rightRnd=lastPointNo;
		} else {
			int  old=rS->swsData[rB].rightRnd;
			if ( pts[old].x < pts[lastPointNo].x ) rS->swsData[rB].rightRnd=lastPointNo;
		}
	} else {
		SweepTree* lE=static_cast <SweepTree*> (lS->swsData[lB].misc);
		if ( lE && lE->rightElem ) {
			SweepTree* rlE=static_cast <SweepTree*> (lE->rightElem);
			chgts[nCh].rSrc=rlE->src;
			chgts[nCh].rBrd=rlE->bord;
		} else {
			chgts[nCh].rSrc=NULL;
			chgts[nCh].rBrd=-1;
		}
	}
}
void              Shape::Validate(void)
{
	for (int i=0;i<nbPt;i++) {
		pData[i].rx=pts[i].x;
		pData[i].ry=pts[i].y;
	}
	for (int i=0;i<nbAr;i++) {
		eData[i].rdx=aretes[i].dx;
		eData[i].rdy=aretes[i].dy;
	}
	for (int i=0;i<nbAr;i++) {
		for (int j=i+1;j<nbAr;j++) {
			float atx,aty,atL,atR;
			if ( TesteIntersection(this,this,i,j,atx,aty,atL,atR,false) ) {
				printf("%i %i  %f %f \n",i,j,atx,aty);
			}
		}
	}
	fflush(stdout);
}

void              Shape::CheckEdges(int lastPointNo,int lastChgtPt,Shape* a,Shape* b,BooleanOp mod)
{

	for (int cCh=0;cCh<nbChgt;cCh++) {
		if ( chgts[cCh].type == 0 ) {
			Shape* lS=chgts[cCh].src;
			int    lB=chgts[cCh].bord;
			lS->swsData[lB].curPoint=chgts[cCh].ptNo;
		}
	}
	for (int cCh=0;cCh<nbChgt;cCh++) {
//		int   chLeN=chgts[cCh].ptNo;
//		int   chRiN=chgts[cCh].ptNo;
		if ( chgts[cCh].src) {
			Shape* lS=chgts[cCh].src;
			int    lB=chgts[cCh].bord;
			Avance(lastPointNo,lastChgtPt,lS,lB,a,b,mod);
		}
		if ( chgts[cCh].osrc ) {
			Shape* rS=chgts[cCh].osrc;
			int    rB=chgts[cCh].obord;
			Avance(lastPointNo,lastChgtPt,rS,rB,a,b,mod);
		}
		if ( chgts[cCh].lSrc ) {
			Shape* nSrc=chgts[cCh].lSrc;
			int    nBrd=chgts[cCh].lBrd;
			while ( nSrc->swsData[nBrd].leftRnd >= lastChgtPt /*&& nSrc->swsData[nBrd].doneTo < lastChgtPt*/ ) {
				Avance(lastPointNo,lastChgtPt,nSrc,nBrd,a,b,mod);

				SweepTree* node=static_cast <SweepTree*> (nSrc->swsData[nBrd].misc);
				if ( node == NULL ) break;
				node=static_cast <SweepTree*> (node->leftElem);
				if ( node == NULL ) break;
				nSrc=node->src;
				nBrd=node->bord;
			}
		}
		if ( chgts[cCh].rSrc ) {
			Shape* nSrc=chgts[cCh].rSrc;
			int    nBrd=chgts[cCh].rBrd;
			while ( nSrc->swsData[nBrd].rightRnd >= lastChgtPt /*&& nSrc->swsData[nBrd].doneTo < lastChgtPt*/ ) {
				Avance(lastPointNo,lastChgtPt,nSrc,nBrd,a,b,mod);

				SweepTree* node=static_cast <SweepTree*> (nSrc->swsData[nBrd].misc);
				if ( node == NULL ) break;
				node=static_cast <SweepTree*> (node->rightElem);
				if ( node == NULL ) break;
				nSrc=node->src;
				nBrd=node->bord;
			}
		}
	}
}

void              Shape::Avance(int lastPointNo,int lastChgtPt,Shape* lS,int lB,Shape* a,Shape* b,BooleanOp mod)
{
	float   dd=HalfRound(1);
	bool    avoidDiag=false;
//	if ( lastChgtPt > 0 && pts[lastChgtPt-1].y+dd == pts[lastChgtPt].y ) avoidDiag=true;

	bool   direct=true;
	if ( lS == b && ( mod == bool_op_diff || mod == bool_op_symdiff ) ) direct=false;
	int   lftN=lS->swsData[lB].leftRnd;
	int   rgtN=lS->swsData[lB].rightRnd;
	if ( lS->swsData[lB].doneTo < lastChgtPt ) {
		int    lp=lS->swsData[lB].curPoint;
		if ( lp >= 0 && pts[lp].y+dd == pts[lastChgtPt].y ) avoidDiag=true;
		if ( lS->eData[lB].rdy == 0 ) {
			// tjs de gauche a droite et pas de diagonale
			if ( lS->eData[lB].rdx >= 0 ) {
				for (int p=lftN;p<=rgtN;p++) {
					DoEdgeTo(lS,lB,p,direct,true);
					lp=p;
				}
			} else {
				for (int p=lftN;p<=rgtN;p++) {
					DoEdgeTo(lS,lB,p,direct,false);
					lp=p;
				}
			}
		} else if ( lS->eData[lB].rdy > 0 ) {
			if ( lS->eData[lB].rdx >= 0 ) {

				for (int p=lftN;p<=rgtN;p++) {
					if ( avoidDiag && p == lftN && pts[lftN].x == pts[lp].x+dd ) {
						if ( lftN > 0 && lftN-1 >= lastChgtPt && pts[lftN-1].x == pts[lp].x ) {
							DoEdgeTo(lS,lB,lftN-1,direct,true);
							DoEdgeTo(lS,lB,lftN,direct,true);
						} else {
							DoEdgeTo(lS,lB,lftN,direct,true);
						}
					} else {
						DoEdgeTo(lS,lB,p,direct,true);
					}
					lp=p;
				}
			} else {

				for (int p=rgtN;p>=lftN;p--) {
					if ( avoidDiag && p == rgtN && pts[rgtN].x == pts[lp].x-dd ) {
						if ( rgtN < nbPt && rgtN+1 < lastPointNo && pts[rgtN+1].x == pts[lp].x ) {
							DoEdgeTo(lS,lB,rgtN+1,direct,true);
							DoEdgeTo(lS,lB,rgtN,direct,true);
						} else {
							DoEdgeTo(lS,lB,rgtN,direct,true);
						}
					} else {
						DoEdgeTo(lS,lB,p,direct,true);
					}
					lp=p;
				}
			}
		} else {
			if ( lS->eData[lB].rdx >= 0 ) {

				for (int p=rgtN;p>=lftN;p--) {
					if ( avoidDiag && p == rgtN && pts[rgtN].x == pts[lp].x-dd ) {
						if ( rgtN < nbPt && rgtN+1 < lastPointNo && pts[rgtN+1].x == pts[lp].x ) {
							DoEdgeTo(lS,lB,rgtN+1,direct,false);
							DoEdgeTo(lS,lB,rgtN,direct,false);
						} else {
							DoEdgeTo(lS,lB,rgtN,direct,false);
						}
					} else {
						DoEdgeTo(lS,lB,p,direct,false);
					}
					lp=p;
				}
			} else {

				for (int p=lftN;p<=rgtN;p++) {
					if ( avoidDiag && p == lftN && pts[lftN].x == pts[lp].x+dd ) {
						if ( lftN > 0 && lftN-1 >= lastChgtPt && pts[lftN-1].x == pts[lp].x ) {
							DoEdgeTo(lS,lB,lftN-1,direct,false);
							DoEdgeTo(lS,lB,lftN,direct,false);
						} else {
							DoEdgeTo(lS,lB,lftN,direct,false);
						}
					} else {
						DoEdgeTo(lS,lB,p,direct,false);
					}
					lp=p;
				}
			}
		}
		lS->swsData[lB].curPoint=lp;
	}
	lS->swsData[lB].doneTo=lastPointNo-1;
}
void              Shape::DoEdgeTo(Shape* iS,int iB,int iTo,bool direct,bool sens)
{
	int   lp=iS->swsData[iB].curPoint;
	int   ne=-1;
	if ( sens ) {
		if ( direct ) ne=AddEdge(lp,iTo); else ne=AddEdge(iTo,lp);
	} else {
		if ( direct ) ne=AddEdge(iTo,lp); else ne=AddEdge(lp,iTo);
	}
	if ( ne >= 0 && HasBackData() ) {
		ebData[ne].pathID=iS->ebData[iB].pathID;
		ebData[ne].pieceID=iS->ebData[iB].pieceID;
		if ( iS->eData[iB].length < 0.00001 ) {
			ebData[ne].tSt=ebData[ne].tEn=iS->ebData[iB].tSt;
		} else {
			float   bdl=iS->eData[iB].ilength;
			float bpx=iS->pData[iS->aretes[iB].st].rx;
			float bpy=iS->pData[iS->aretes[iB].st].ry;
			float bdx=iS->eData[iB].rdx;
			float bdy=iS->eData[iB].rdy;
			float psx=pts[aretes[ne].st].x;
			float psy=pts[aretes[ne].st].y;
			float pex=pts[aretes[ne].en].x;
			float pey=pts[aretes[ne].en].y;
			float pst=((psx-bpx)*bdx+(psy-bpy)*bdy)*bdl;
			float pet=((pex-bpx)*bdx+(pey-bpy)*bdy)*bdl;
			pst=iS->ebData[iB].tSt*(1-pst)+iS->ebData[iB].tEn*pst;
			pet=iS->ebData[iB].tSt*(1-pet)+iS->ebData[iB].tEn*pet;
			ebData[ne].tEn=pet;
			ebData[ne].tSt=pst;
		}
	}
	iS->swsData[iB].curPoint=iTo;
	if ( ne >= 0 ) {
		int  cp=iS->swsData[iB].firstLinkedPoint;
		swsData[ne].firstLinkedPoint=iS->swsData[iB].firstLinkedPoint;
		while ( cp >= 0 ) {
			pData[cp].askForWindingB=ne;
			cp=pData[cp].nextLinkedPoint;
		}
		iS->swsData[iB].firstLinkedPoint=-1;
	}
}


