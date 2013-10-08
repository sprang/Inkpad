//
//  DBLog.h
//  Dropbox
//
//  Created by Will Stockwell on 11/4/10.
//  Copyright 2010 Dropbox, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

#if !defined(NS_FORMAT_FUNCTION)
#define NS_FORMAT_FUNCTION(F, A)
#endif

typedef enum {
	DBLogLevelInfo = 0,
	DBLogLevelAnalytics,
	DBLogLevelWarning,
	DBLogLevelError,
	DBLogLevelFatal
} DBLogLevel;

typedef void DBLogCallback(DBLogLevel logLevel, NSString *format, va_list args);

NSString * DBLogFilePath(void);
void DBSetupLogToFile(void);

NSString* DBStringFromLogLevel(DBLogLevel logLevel);


void DBLogSetLevel(DBLogLevel logLevel);
void DBLogSetCallback(DBLogCallback *callback);

void DBLog(DBLogLevel logLevel, NSString *format, ...) NS_FORMAT_FUNCTION(2,3);
void DBLogInfo(NSString *format, ...) NS_FORMAT_FUNCTION(1,2);
void DBLogWarning(NSString *format, ...) NS_FORMAT_FUNCTION(1,2);
void DBLogError(NSString *format, ...) NS_FORMAT_FUNCTION(1,2);
void DBLogFatal(NSString *format, ...) NS_FORMAT_FUNCTION(1,2);