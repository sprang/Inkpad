//
//  DBRestRequest.h
//  DropboxSDK
//
//  Created by Brian Smith on 4/9/10.
//  Copyright 2010 Dropbox, Inc. All rights reserved.
//


@protocol DBNetworkRequestDelegate;

/* DBRestRequest will download a URL either into a file that you provied the name to or it will
   create an NSData object with the result. When it has completed downloading the URL, it will
   notify the target with a selector that takes the DBRestRequest as the only parameter. */
@interface DBRequest : NSObject {
    NSURLRequest* request;
    id target;
    SEL selector;
    NSURLConnection* urlConnection;
    NSFileHandle* fileHandle;
    NSFileManager* fileManager;

    SEL failureSelector;
    SEL downloadProgressSelector;
    SEL uploadProgressSelector;
    NSString* resultFilename;
    NSString* tempFilename;
    NSDictionary* userInfo;
    NSString *sourcePath;

    NSHTTPURLResponse* response;
    NSDictionary* xDropboxMetadataJSON;
    NSInteger bytesDownloaded;
    CGFloat downloadProgress;
    CGFloat uploadProgress;
    NSMutableData* resultData;
    NSError* error;
}

/*  Set this to get called when _any_ request starts or stops. This should hook into whatever
    network activity indicator system you have. */
+ (void)setNetworkRequestDelegate:(id<DBNetworkRequestDelegate>)delegate;

/*  This constructor downloads the URL into the resultData object */
- (id)initWithURLRequest:(NSURLRequest*)request andInformTarget:(id)target selector:(SEL)selector;

/*  Cancels the request and prevents it from sending additional messages to the delegate. */
- (void)cancel;

/* If there is no error, it will parse the response as JSON and make sure the JSON object is the
   correct type. If not, it will set the error object with an error code of DBErrorInvalidResponse */
- (id)parseResponseAsType:(Class)cls;

@property (nonatomic, assign) SEL failureSelector; // To send failure events to a different selector set this
@property (nonatomic, assign) SEL downloadProgressSelector; // To receive download progress events set this
@property (nonatomic, assign) SEL uploadProgressSelector; // To receive upload progress events set this
@property (nonatomic, retain) NSString* resultFilename; // The file to put the HTTP body in, otherwise body is stored in resultData
@property (nonatomic, retain) NSDictionary* userInfo;
@property (nonatomic, retain) NSString *sourcePath; // Used by methods that upload to refresh the input stream

@property (nonatomic, readonly) NSURLRequest* request;
@property (nonatomic, readonly) NSHTTPURLResponse* response;
@property (nonatomic, readonly) NSDictionary* xDropboxMetadataJSON;
@property (nonatomic, readonly) NSInteger statusCode;
@property (nonatomic, readonly) CGFloat downloadProgress;
@property (nonatomic, readonly) CGFloat uploadProgress;
@property (nonatomic, readonly) NSData* resultData;
@property (nonatomic, readonly) NSString* resultString;
@property (nonatomic, readonly) NSObject* resultJSON;
@property (nonatomic, readonly) NSError* error;

@end


@protocol DBNetworkRequestDelegate 

- (void)networkRequestStarted;
- (void)networkRequestStopped;

@end
