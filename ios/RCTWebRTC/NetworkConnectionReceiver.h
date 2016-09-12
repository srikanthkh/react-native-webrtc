//
//  NetworkConnectionReceiver.h
//  Vidao
//
//  Created by sukha gill on 2016-08-30.
//  Copyright © 2016 Facebook. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Reachability.h"

typedef NS_ENUM(NSUInteger, ConnectivityType) {
    Connectivity_2G = 0,
    Connectivity_3G,
    Connectivity_LTE,
    Connectivity_WIFI
};

@interface NetworkConnectionReceiver : NSObject

-(int) getBandwidthValueFromReachability:(Reachability *)currentReachability;
-(NSString *)getConnectivityType;

@end
