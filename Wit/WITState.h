//
//  WITState.h
//  Wit
//
//  Created by Willy Blandin on 12. 10. 29..
//  Copyright (c) 2012년 Willy Blandin. All rights reserved.
//

#import "WITUploader.h"
#import "WITRecorder.h"
#import "WITThread.h"

@interface WITState : NSObject
@property (strong) NSString* resourcePath;
@property (strong) WITRecorder* recorder;
@property (strong) WITUploader* uploader;
@property (strong) NSString *accessToken;
@property (strong) NSMutableDictionary *context;
@property (strong) WITThread *thread;

+(WITState*)sharedInstance;
+(NSString*)UUID;
+(NSBundle*)frameworkBundle;
@end
