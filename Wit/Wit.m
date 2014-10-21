//
//  Created by Willy Blandin on 12. 8. 16..
//  Copyright (c) 2012년 Willy Blandin. All rights reserved.
//

#import "WitPrivate.h"
#import "WITState.h"
#import "WITRecorder.h"
#import "WITUploader.h"
#import "util.h"
#import "WITRecordingSession.h"

@interface Wit ()  
@property (strong) WITState *state;
@property WITRecordingSession *recordingSession;
@end

@implementation Wit {
}
@synthesize delegate, state;

#pragma mark - Public API
- (void)toggleCaptureVoiceIntent:(id)sender {
    [self toggleCaptureVoiceIntent:sender withCustomData:nil];
}

- (void)toggleCaptureVoiceIntent:(id)sender withCustomData:(id) customData {
    if ([self isRecording]) {
        [self stop];
    } else {
        [self start:sender customData:customData];
    }
}

- (void)start {
    [self start:nil customData:nil];
}


- (void)start:(id)sender customData:(id)customData {
    self.recordingSession = [[WITRecordingSession alloc] initWithWitContext:state.context
                                                                 vadEnabled:[Wit sharedInstance].detectSpeechStop withToggleStarter:sender withWitToken:[WITState sharedInstance].accessToken
                                                               withDelegate:self];
    self.recordingSession.customData = customData;
    self.recordingSession.delegate = self;
}

- (void)stop{
    [self.recordingSession stop];
    self.recordingSession = nil;
}

- (BOOL)isRecording {
    return [self.recordingSession isRecording];
}

- (void) interpretString: (NSString *) string customData:(id)customData {
    NSDate *start = [NSDate date];
    NSMutableURLRequest* req = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:[NSString stringWithFormat:@"https://api.wit.ai/message?q=%@&v=%@", urlencodeString(string), kWitAPIVersion]]];
    [req setCachePolicy:NSURLRequestReloadIgnoringLocalCacheData];
    [req setTimeoutInterval:15.0];
    [req setValue:[NSString stringWithFormat:@"Bearer %@", self.accessToken] forHTTPHeaderField:@"Authorization"];
    [req setValue:@"application/json" forHTTPHeaderField:@"Accept"];
    [NSURLConnection sendAsynchronousRequest:req
                                       queue:[NSOperationQueue mainQueue]
                           completionHandler:^(NSURLResponse *response, NSData *data, NSError *connectionError) {
                               if (WIT_DEBUG) {
                                   NSTimeInterval t = [[NSDate date] timeIntervalSinceDate:start];
                                   NSLog(@"Wit response (%f s) %@",
                                         t, [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]);
                               }
                               
                               if (connectionError) {
                                   [self gotResponse:nil customData:customData error:connectionError];
                                   return;
                               }
                               
                               NSError *serializationError;
                               NSDictionary *object = [NSJSONSerialization JSONObjectWithData:data
                                                                                      options:0
                                                                                        error:&serializationError];
                               if (serializationError) {
                                   [self gotResponse:nil customData:customData error:serializationError];
                                   return;
                               }
                               
                               if (object[@"error"]) {
                                   NSDictionary *infos = @{NSLocalizedDescriptionKey: object[@"error"],
                                                           kWitKeyError: object[@"code"]};
                                   [self gotResponse:nil customData:customData
                                               error:[NSError errorWithDomain:@"WitProcessing"
                                                                         code:1
                                                                     userInfo:infos]];
                                   return;
                               }
                               
                               [self gotResponse:object customData:customData error:nil];
                           }];
}

#pragma mark - Context management
-(void)setContext:(NSDictionary *)dict {
    NSMutableDictionary* newContext = [state.context mutableCopy];
    if (!newContext) {
        newContext = [@{} mutableCopy];
    }

    [dict enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
        newContext[key] = obj;
    }];

    state.context = newContext;
}

-(NSDictionary*)getContext {
    return state.context;
}

#pragma mark - WITUploaderDelegate
- (void)gotResponse:(NSDictionary*)resp customData:(id)customData error:(NSError*)err {
    if (err) {
        [self error:err customData:customData];
        return;
    }
    [self processMessage:resp customData:customData];
}

#pragma mark - Response processing
- (void)errorWithDescription:(NSString*)errorDesc customData:(id)customData {
    NSError* e = [NSError errorWithDomain:@"WitProcessing" code:1 userInfo:@{NSLocalizedDescriptionKey: errorDesc}];
    [self error:e customData:customData];
}

- (void)processMessage:(NSDictionary *)resp customData:(id)customData {
    id error = resp[kWitKeyError];
    if (error) {
        NSString* errorDesc = [NSString stringWithFormat:@"Code %@: %@", error[@"code"], error[@"message"]];
        return [self errorWithDescription:errorDesc customData:customData];
    }

    NSDictionary* outcome = resp[kWitKeyOutcome];
    if (!outcome) {
        return [self errorWithDescription:@"No outcome" customData:customData];
    }

    NSString *intent = outcome[@"intent"];
    if ((id)intent == [NSNull null]) {
        return [self errorWithDescription:@"Intent was null" customData:customData];
    }
    NSString *messageId = resp[kWitKeyMsgId];
    NSString *confidenceString = outcome[kWitKeyConfidence];
    NSNumber *confidence = [[NSNumber alloc] initWithFloat:[confidenceString floatValue]];
    NSDictionary *entities = outcome[@"entities"];
    
    [self.delegate witDidGraspIntent:intent entities:entities body:resp[kWitKeyBody] messageId:messageId confidence:confidence customData:customData error:error];
    
}

- (void)error:(NSError*)e customData:(id)customData; {
    [self.delegate witDidGraspIntent:nil entities:nil body:nil messageId:nil confidence:nil customData:customData error:e];
}

#pragma mark - Getters and setters
- (NSString *)accessToken {
    return state.accessToken;
}

- (void)setAccessToken:(NSString *)accessToken {
    state.accessToken = accessToken;
}

#pragma mark - Lifecycle
- (void)initialize {
    state = [WITState sharedInstance];
    self.detectSpeechStop = NO;
}
- (id)init {
    self = [super init];
    if (self) {
        [self initialize];
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

+ (Wit *)sharedInstance {
    static Wit *instance;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        instance = [[Wit alloc] init];
    });

    return instance;
}

#pragma mark - WITRecordingSessionDelegate

-(void)recordingSessionActivityDetectorStarted {
    if ([self.delegate respondsToSelector:@selector(witActivityDetectorStarted)]) {
        [self.delegate witActivityDetectorStarted];
    }
}

-(void)recordingSessionDidStartRecording {
    if ([self.delegate respondsToSelector:@selector(witDidStartRecording)]) {
        [self.delegate witDidStartRecording];
    }
}

-(void)recordingSessionDidStopRecording {
    if ([self.delegate respondsToSelector:@selector(witDidStopRecording)]) {
        [self.delegate witDidStopRecording];
    }
}

-(void)recordingSessionRecorderGotChunk:(NSData *)chunk {

}

-(void)recordingSessionRecorderPowerChanged:(float)power {
    
}

-(void)recordingSessionGotResponse:(NSDictionary *)resp customData:(id)customData error:(NSError *)err {
    [self gotResponse:resp customData:customData error:err];
}

@end
