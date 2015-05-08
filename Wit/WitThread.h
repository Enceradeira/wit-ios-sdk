//
// Created by Jorg on 08/05/15.
// Copyright (c) 2015 Willy Blandin. All rights reserved.
//

#import <Foundation/Foundation.h>


@interface WITThread : NSObject
- (instancetype)initWithId:(NSString *)threadId;

- (NSString *)toUrlParameter;
@end