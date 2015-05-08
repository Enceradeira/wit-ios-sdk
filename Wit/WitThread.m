//
// Created by Jorg on 08/05/15.
// Copyright (c) 2015 Willy Blandin. All rights reserved.
//

#import "WITThread.h"
#import "util.h"


@implementation WITThread {

    NSString *_threadId;
}
- (instancetype)initWithId:(NSString *)threadId {
    self = [super init];
    if (self != nil) {
        _threadId = threadId == nil ? @"" : threadId;
    }
    return self;
}

- (NSString *)toUrlParameter {
    NSString *threadIdEncoded = urlencodeString(_threadId);
    return [threadIdEncoded isEqualToString:@""] ? @"" : [NSString stringWithFormat:@"&thread_id=%@", threadIdEncoded];
}

@end