//
//  MPDebug.h
//  MPOAuthConnection
//
//  Created by Karl Adam on 09.02.06.
//  Copyright 2009 matrixPointer. All rights reserved.
//

// Removing oauth logging for now, set to '#ifdef DEBUG' to re-enable
#if 0
	#define MPLog(...) NSLog(__VA_ARGS__)
#else
	#define MPLog(...) do { } while (0)
#endif
