/*
 *  AVL.h
 *  nlivarot
 *
 *  Created by fred on Mon Jun 16 2003.
 *
 */

#ifndef my_avl
#define my_avl

#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
//#include <iostream.h>

#include "DblLinked.h"

class AVLTree : public DblLinked {
public:
	AVLTree*         dad;
	AVLTree*         sonL;
	AVLTree*         sonR;
	
	int              balance;

//	AVLTree*         leftElem;
//	AVLTree*         rightElem;
	
	AVLTree(void);
	~AVLTree(void);

	void        MakeNew(void);
	void        MakeDelete(void);

	int         Remove(AVLTree* &racine,bool rebalance=true);
	int         Remove(AVLTree* &racine,AVLTree* &startNode,int &diff);

	int         Insert(AVLTree* &racine,int insertType,AVLTree* insertL,AVLTree* insertR,bool rebalance);
	int         Insert(AVLTree* &racine,int insertType,AVLTree* insertL,AVLTree* insertR);

	AVLTree*    LeftLeaf(AVLTree* from,bool from_dad);
	AVLTree*    RightLeaf(AVLTree* from,bool from_dad);

	AVLTree*    Leftmost(void);

	int         RestoreBalances(AVLTree* from,AVLTree* &racine);
	int         RestoreBalances(int diff,AVLTree* &racine);

	void        Relocate(AVLTree* to);
};

#endif


