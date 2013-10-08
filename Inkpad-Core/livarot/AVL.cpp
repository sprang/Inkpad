/*
 *  AVL.cpp
 *  nlivarot
 *
 *  Created by fred on Mon Jun 16 2003.
 *
 */

#include "AVL.h"
#include "LivarotDefs.h"

AVLTree::AVLTree(void):DblLinked()
{
	dad=sonL=sonR=NULL;
	balance=0;
}
AVLTree::~AVLTree(void)
{
}
void        AVLTree::MakeNew(void)
{
DblLinked::MakeNew();
	dad=sonL=sonR=NULL;
	balance=0;
}
void        AVLTree::MakeDelete(void)
{
DblLinked::MakeDelete();
}
AVLTree*    AVLTree::Leftmost(void)
{
	return LeftLeaf(NULL,true);
}

AVLTree*    AVLTree::LeftLeaf(AVLTree* from,bool from_dad)
{
	if ( from_dad ) {
		if ( sonL ) {
			return sonL->LeftLeaf(this,true);
		} else {
			return this;
		}
	} else {
		if ( from == sonR ) {
			if ( sonL ) {
				return sonL->LeftLeaf(this,true);
			} else if ( dad ) {
				return dad->LeftLeaf(this,false);
			} else {
				return NULL;
			}
		} else if ( from == sonL ) {
			if ( dad ) {
				return dad->LeftLeaf(this,false);
			} else {
				return NULL;
			}
		} else {
			return NULL;
		}
	}
	return NULL;
}
AVLTree*    AVLTree::RightLeaf(AVLTree* from,bool from_dad)
{
	if ( from_dad ) {
		if ( sonR ) {
			return sonR->RightLeaf(this,true);
		} else {
			return this;
		}
	} else {
		if ( from == sonL ) {
			if ( sonR ) {
				return sonR->RightLeaf(this,true);
			} else if ( dad ) {
				return dad->RightLeaf(this,false);
			} else {
				return NULL;
			}
		} else if ( from == sonR ) {
			if ( dad ) {
				return dad->RightLeaf(this,false);
			} else {
				return NULL;
			}
		} else {
			return NULL;
		}
	}
	return NULL;
}
int
AVLTree::RestoreBalances(AVLTree* from,AVLTree* &racine)
{
	if ( from == NULL ) {
		if ( dad ) return dad->RestoreBalances(this,racine);
	} else {
		if ( balance == 0 ) {
			if ( from == sonL ) balance=1;
			if ( from == sonR ) balance=-1;
			if ( dad ) return dad->RestoreBalances(this,racine);
			return avl_no_err;
		} else if ( balance > 0 ) {
			if ( from == sonR ) {
				balance=0;
				return avl_no_err;
			}
			if ( sonL == NULL ) {
//				cout << "mierda\n";
				return avl_bal_err;
			}
			AVLTree*  a=this;
			AVLTree*  b=sonL;
			AVLTree*  e=sonR;
			AVLTree*  c=sonL->sonL;
			AVLTree*  d=sonL->sonR;
			if ( sonL->balance > 0 ) {
				AVLTree*  r=dad;

				a->dad=b;
				b->sonR=a;
				a->sonR=e;
				if ( e ) e->dad=a;
				a->sonL=d;
				if ( d ) d->dad=a;
				b->sonL=c;
				if ( c ) c->dad=b;
				b->dad=r;
				if ( r ) {
					if ( r->sonL == a ) r->sonL=b;
					if ( r->sonR == a ) r->sonR=b;
				}
				if ( racine == a ) racine=b;

				a->balance=0;
				b->balance=0;
				return avl_no_err;
			} else {
				if ( sonL->sonR == NULL ) {
	//				cout << "mierda\n";
					return avl_bal_err;
				}
				AVLTree*  f=sonL->sonR->sonL;
				AVLTree*  g=sonL->sonR->sonR;
				AVLTree*  r=dad;

				a->dad=d;
				d->sonR=a;
				b->dad=d;
				d->sonL=b;
				a->sonL=g;
				if ( g ) g->dad=a;
				a->sonR=e;
				if ( e ) e->dad=a;
				b->sonL=c;
				if ( c ) c->dad=b;
				b->sonR=f;
				if ( f ) f->dad=b;

				d->dad=r;
				if ( r ) {
					if ( r->sonL == a ) r->sonL=d;
					if ( r->sonR == a ) r->sonR=d;
				}
				if ( racine == a ) racine=d;
				
				int old_bal=d->balance;
				d->balance=0;
				if ( old_bal == 0 ) {
					a->balance=0;
					b->balance=0;
				} else if ( old_bal > 0 ) {
					a->balance=-1;
					b->balance=0;
				} else if ( old_bal < 0 ) {
					a->balance=0;
					b->balance=1;
				}
				return avl_no_err;
			}
		} else if ( balance < 0 ) {
			if ( from == sonL ) {
				balance=0;
				return avl_no_err;
			}
			if ( sonR == NULL ) {
//				cout << "mierda\n";
				return avl_bal_err;
			}
			AVLTree*  a=this;
			AVLTree*  b=sonR;
			AVLTree*  e=sonL;
			AVLTree*  c=sonR->sonR;
			AVLTree*  d=sonR->sonL;
			AVLTree*  r=dad;
			if ( sonR->balance < 0 ) {

				a->dad=b;
				b->sonL=a;
				a->sonL=e;
				if ( e ) e->dad=a;
				a->sonR=d;
				if ( d ) d->dad=a;
				b->sonR=c;
				if ( c ) c->dad=b;
				b->dad=r;
				if ( r ) {
					if ( r->sonL == a ) r->sonL=b;
					if ( r->sonR == a ) r->sonR=b;
				}
				if ( racine == a ) racine=b;
				a->balance=0;
				b->balance=0;
				return avl_no_err;
			} else {
				if ( sonR->sonL == NULL ) {
//					cout << "mierda\n";
					return avl_bal_err;
				}
				AVLTree*  f=sonR->sonL->sonR;
				AVLTree*  g=sonR->sonL->sonL;

				a->dad=d;
				d->sonL=a;
				b->dad=d;
				d->sonR=b;
				a->sonR=g;
				if ( g ) g->dad=a;
				a->sonL=e;
				if ( e ) e->dad=a;
				b->sonR=c;
				if ( c ) c->dad=b;
				b->sonL=f;
				if ( f ) f->dad=b;

				d->dad=r;
				if ( r ) {
					if ( r->sonL == a ) r->sonL=d;
					if ( r->sonR == a ) r->sonR=d;
				}
				if ( racine == a ) racine=d;
				int old_bal=d->balance;
				d->balance=0;
				if ( old_bal == 0 ) {
					a->balance=0;
					b->balance=0;
				} else if ( old_bal > 0 ) {
					a->balance=0;
					b->balance=-1;
				} else if ( old_bal < 0 ) {
					a->balance=1;
					b->balance=0;
				}
				return avl_no_err;
			}
		}
	}
	return avl_no_err;
}

int 
AVLTree::RestoreBalances(int diff,AVLTree* &racine)
{	
	if ( balance > 0 ) {
		if ( diff < 0 ) {
			balance=0;
			if ( dad ) {
				if ( this == dad->sonR ) return dad->RestoreBalances(1,racine);
				if ( this == dad->sonL ) return dad->RestoreBalances(-1,racine);
			}
			return avl_no_err;
		} else if ( diff == 0 ) {
		} else if ( diff > 0 ) {
			if ( sonL == NULL ) {
//				cout << "un probleme\n";
				return avl_bal_err;
			}
			AVLTree*  r=dad;
			AVLTree*  a=this;
			AVLTree*  b=sonR;
			AVLTree*  e=sonL;
			AVLTree*  f=e->sonR;
			AVLTree*  g=e->sonL;
			if ( e->balance > 0 ) {
				e->sonR=a;
				e->sonL=g;
				a->sonR=b;
				a->sonL=f;
				if ( a ) a->dad=e;
				if ( g ) g->dad=e;
				if ( b ) b->dad=a;
				if ( f ) f->dad=a;
				e->dad=r;
				if ( r ) {
					if ( r->sonL == a ) r->sonL=e;
					if ( r->sonR == a ) r->sonR=e;
				}
				if ( racine == this ) racine=e;
				e->balance=0;
				a->balance=0;
				if ( r ) {
					if ( e == r->sonR ) return r->RestoreBalances(1,racine);
					if ( e == r->sonL ) return r->RestoreBalances(-1,racine);
				}
				return avl_no_err;
			} else if ( e->balance == 0 ) {
				e->sonR=a;
				e->sonL=g;
				a->sonR=b;
				a->sonL=f;
				if ( a ) a->dad=e;
				if ( g ) g->dad=e;
				if ( b ) b->dad=a;
				if ( f ) f->dad=a;
				e->dad=r;
				if ( r ) {
					if ( r->sonL == a ) r->sonL=e;
					if ( r->sonR == a ) r->sonR=e;
				}
				if ( racine == this ) racine=e;
				e->balance=-1;
				a->balance=1;
				return avl_no_err;
			} else if ( e->balance < 0 ) {
				if ( sonL->sonR == NULL ) {
//					cout << "un probleme\n";
					return avl_bal_err;
				}
				AVLTree*  i=sonL->sonR->sonR;
				AVLTree*  j=sonL->sonR->sonL;

				f->sonR=a;
				f->sonL=e;
				a->sonR=b;
				a->sonL=i;
				e->sonR=j;
				e->sonL=g;
				if ( b ) b->dad=a;
				if ( i ) i->dad=a;
				if ( g ) g->dad=e;
				if ( j ) j->dad=e;
				if ( a ) a->dad=f;
				if ( e ) e->dad=f;
				f->dad=r;
				if ( r ) {
					if ( r->sonL == a ) r->sonL=f;
					if ( r->sonR == a ) r->sonR=f;
				}
				if ( racine == this ) racine=f;
				int   oBal=f->balance;
				f->balance=0;
				if ( oBal > 0 ) {
					a->balance=-1;
					e->balance=0;
				} else if ( oBal == 0 ) {
					a->balance=0;
					e->balance=0;
				} else if ( oBal < 0 ) {
					a->balance=0;
					e->balance=1;
				}
				if ( r ) {
					if ( f == r->sonR ) return r->RestoreBalances(1,racine);
					if ( f == r->sonL ) return r->RestoreBalances(-1,racine);
				}
				return avl_no_err;
			}
		}
	} else if ( balance == 0 ) {
		if ( diff < 0 ) {
			balance=-1;
		} else if ( diff == 0 ) {
		} else if ( diff > 0 ) {
			balance=1;
		}
		return avl_no_err;
	} else if ( balance < 0 ) {
		if ( diff < 0 ) {
			if ( sonR == NULL ) {
//				cout << "un probleme\n";
				return avl_bal_err;
			}
			AVLTree*  r=dad;
			AVLTree*  a=this;
			AVLTree*  b=sonL;
			AVLTree*  e=sonR;
			AVLTree*  f=e->sonL;
			AVLTree*  g=e->sonR;
			if ( e->balance < 0 ) {
				e->sonL=a;
				e->sonR=g;
				a->sonL=b;
				a->sonR=f;
				if ( a ) a->dad=e;
				if ( g ) g->dad=e;
				if ( b ) b->dad=a;
				if ( f ) f->dad=a;
				e->dad=r;
				if ( r ) {
					if ( r->sonL == a ) r->sonL=e;
					if ( r->sonR == a ) r->sonR=e;
				}
				if ( racine == this ) racine=e;
				e->balance=0;
				a->balance=0;
				if ( r ) {
					if ( e == r->sonR ) return r->RestoreBalances(1,racine);
					if ( e == r->sonL ) return r->RestoreBalances(-1,racine);
				}
				return avl_no_err;
			} else if ( e->balance == 0 ) {
				e->sonL=a;
				e->sonR=g;
				a->sonL=b;
				a->sonR=f;
				if ( a ) a->dad=e;
				if ( g ) g->dad=e;
				if ( b ) b->dad=a;
				if ( f ) f->dad=a;
				e->dad=r;
				if ( r ) {
					if ( r->sonL == a ) r->sonL=e;
					if ( r->sonR == a ) r->sonR=e;
				}
				if ( racine == this ) racine=e;
				e->balance=1;
				a->balance=-1;
				return avl_no_err;
			} else if ( e->balance > 0 ) {
				if ( sonR->sonL == NULL ) {
//					cout << "un probleme\n";
					return avl_bal_err;
				}
				AVLTree*  i=sonR->sonL->sonL;
				AVLTree*  j=sonR->sonL->sonR;

				f->sonL=a;
				f->sonR=e;
				a->sonL=b;
				a->sonR=i;
				e->sonL=j;
				e->sonR=g;
				if ( b ) b->dad=a;
				if ( i ) i->dad=a;
				if ( g ) g->dad=e;
				if ( j ) j->dad=e;
				if ( a ) a->dad=f;
				if ( e ) e->dad=f;
				f->dad=r;
				if ( r ) {
					if ( r->sonL == a ) r->sonL=f;
					if ( r->sonR == a ) r->sonR=f;
				}
				if ( racine == this ) racine=f;
				int   oBal=f->balance;
				f->balance=0;
				if ( oBal > 0 ) {
					a->balance=0;
					e->balance=-1;
				} else if ( oBal == 0 ) {
					a->balance=0;
					e->balance=0;
				} else if ( oBal < 0 ) {
					a->balance=1;
					e->balance=0;
				}
				if ( r ) {
					if ( f == r->sonR ) return r->RestoreBalances(1,racine);
					if ( f == r->sonL ) return r->RestoreBalances(-1,racine);
				}
				return avl_no_err;
			}
		} else if ( diff == 0 ) {
		} else if ( diff > 0 ) {
			balance=0;
			if ( dad ) {
				if ( this == dad->sonR ) return dad->RestoreBalances(1,racine);
				if ( this == dad->sonL ) return dad->RestoreBalances(-1,racine);
			}
			return avl_no_err;
		}
	}
	return avl_no_err;
}

/*
 * removal
 */
int             AVLTree::Remove(AVLTree* &racine,bool rebalance)
{
	AVLTree* startNode=NULL;
	int      remDiff=0;
	int res=Remove(racine,startNode,remDiff);
	if ( res == avl_no_err &&  rebalance && startNode ) res=startNode->RestoreBalances(remDiff,racine);
	return res;
}
int             AVLTree::Remove(AVLTree* &racine,AVLTree* &startNode,int &diff)
{
DblLinked::Extract();
	
	if ( sonL && sonR ) {
		AVLTree* newMe=sonL->RightLeaf(this,true);
		if ( newMe == NULL || newMe->sonR ) {
//			cout << "pas normal\n";
			return avl_rm_err;
		}
		if ( newMe == sonL ) {
			startNode=newMe;
			diff=-1;
			newMe->sonR=sonR;
			sonR->dad=newMe;
			newMe->dad=dad;
			if ( dad ) {
				if ( dad->sonL == this ) dad->sonL=newMe;
				if ( dad->sonR == this ) dad->sonR=newMe;
			}
		} else {
			AVLTree*  oDad=newMe->dad;
			startNode=oDad;
			diff=1;

			oDad->sonR=newMe->sonL;
			if ( newMe->sonL ) newMe->sonL->dad=oDad;

			newMe->dad=dad;
			newMe->sonL=sonL;
			newMe->sonR=sonR;
			if ( dad ) {
				if ( dad->sonL == this ) dad->sonL=newMe;
				if ( dad->sonR == this ) dad->sonR=newMe;
			}
			if ( sonL ) sonL->dad=newMe;
			if ( sonR ) sonR->dad=newMe;
		}
		newMe->balance=balance;
		if ( racine == this ) racine=newMe;
	} else if ( sonL ) {
		startNode=dad;
		diff=0;
		if ( dad ) {
			if ( this == dad->sonL ) diff=-1;
			if ( this == dad->sonR ) diff=1;
		}
		if ( dad ) {
			if ( dad->sonL == this ) dad->sonL=sonL;
			if ( dad->sonR == this ) dad->sonR=sonL;
		}
		if ( sonL->dad == this ) sonL->dad=dad;
		if ( racine == this ) racine=sonL;
	} else if ( sonR ) {
		startNode=dad;
		diff=0;
		if ( dad ) {
			if ( this == dad->sonL ) diff=-1;
			if ( this == dad->sonR ) diff=1;
		}
		if ( dad ) {
			if ( dad->sonL == this ) dad->sonL=sonR;
			if ( dad->sonR == this ) dad->sonR=sonR;
		}
		if ( sonR->dad == this ) sonR->dad=dad;
		if ( racine == this ) racine=sonR;
	} else {
		startNode=dad;
		diff=0;
		if ( dad ) {
			if ( this == dad->sonL ) diff=-1;
			if ( this == dad->sonR ) diff=1;
		}
		if ( dad ) {
			if ( dad->sonL == this ) dad->sonL=NULL;
			if ( dad->sonR == this ) dad->sonR=NULL;
		}
		if ( racine == this ) racine=NULL;
	}
	dad=sonR=sonL=NULL;
	balance=0;
	return avl_no_err;
}

/*
 * insertion
 */
int             AVLTree::Insert(AVLTree* &racine,int insertType,AVLTree* insertL,AVLTree* insertR,bool rebalance)
{
	int res=Insert(racine,insertType,insertL,insertR);
	if ( res == avl_no_err && rebalance ) res=RestoreBalances((AVLTree*)NULL,racine);
	return res;
}
int             AVLTree::Insert(AVLTree* &racine,int insertType,AVLTree* insertL,AVLTree* insertR)
{
	if ( racine == NULL ) {
		racine=this;
		return avl_no_err;
	} else {
		if ( insertType == not_found ) {
//			cout << "pb avec l'arbre de raster\n";
			return avl_ins_err;
		} else if ( insertType == found_on_left ) {
			if ( insertR == NULL || insertR->sonL ) {
//				cout << "ngou?\n";
				return avl_ins_err;
			}
			insertR->sonL=this;
			dad=insertR;
			InsertOnLeft(insertR);
		} else if ( insertType == found_on_right ) {
			if ( insertL == NULL || insertL->sonR ) {
//				cout << "ngou?\n";
				return avl_ins_err;
			}
			insertL->sonR=this;
			dad=insertL;
			InsertOnRight(insertL);
		} else if ( insertType == found_between ) {
			if ( insertR == NULL || insertL == NULL || ( insertR->sonL != NULL && insertL->sonR != NULL ) ) {
//				cout << "ngou?\n";
				return avl_ins_err;
			}
			if ( insertR->sonL == NULL ) {
				insertR->sonL=this;
				dad=insertR;
			} else if ( insertL->sonR == NULL ) {
				insertL->sonR=this;
				dad=insertL;
			}
			InsertBetween(insertL,insertR);
		} else if ( insertType == found_exact ) {
			if ( insertL == NULL ) {
//				cout << "ngou?\n";
				return avl_ins_err;
			}
			// et on insere

			if ( insertL->sonR ) {
				insertL=insertL->sonR->LeftLeaf(insertL,true);
				if ( insertL->sonL ) {
//					cout << "ngou?\n";
					return avl_ins_err;
				}
				insertL->sonL=this;
				this->dad=insertL;
				InsertBetween(insertL->leftElem,insertL);
			} else {
				insertL->sonR=this;
				dad=insertL;
				InsertBetween(insertL,insertL->rightElem);
			}
		} else {
			//			cout << "code incorrect\n";
			return avl_ins_err;
		}
	}
	return avl_no_err;
}
void         AVLTree::Relocate(AVLTree* to)
{
DblLinked::Relocate(to);
	if ( dad ) {
		if ( dad->sonL == this ) dad->sonL=to;
		if ( dad->sonR == this ) dad->sonR=to;
	}
	if ( sonR ) {
		sonR->dad=to;
	}
	if ( sonL ) {
		sonL->dad=to;
	}
	to->dad=dad;
	to->sonR=sonR;
	to->sonL=sonL;
}
