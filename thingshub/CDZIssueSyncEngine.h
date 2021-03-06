//
//  CDZIssueSyncEngine.h
//  thingshub
//
//  Created by Chris Dzombak on 1/13/14.
//  Copyright (c) 2014 Chris Dzombak. All rights reserved.
//

@class OCTClient;

@interface CDZIssueSyncEngine : NSObject

/// Designated initializer
- (instancetype)initWithAuthenticatedClient:(OCTClient *)client;

@end
