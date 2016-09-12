//
//  NetworkConnectionReceiver.m
//  Vidao
//
//  Created by sukha gill on 2016-08-30.
//  Copyright © 2016 Facebook. All rights reserved.
//

#import "NetworkConnectionReceiver.h"
#import <CoreTelephony/CTTelephonyNetworkInfo.h>
#import <SystemConfiguration/SystemConfiguration.h>



//#import <objc/runtime.h>
//#import <Foundation/Foundation.h>
//
//#import "RCTLog.h"
//#import "RCTUtils.h"
//#import "RCTBridge.h"
//#import "RCTEventDispatcher.h"
//
//#import "RTCICEServer.h"
//#import "RTCPair.h"
//#import "RTCMediaConstraints.h"
//#import "RTCPeerConnection+Block.h"
//#import "RTCICECandidate.h"
//#import "RTCStatsReport.h"
//
////#import "WebRTCModule+RTCMediaStream.h"
////#import "WebRTCModule+RTCPeerConnection.h"
//
//#import "RCTViewManager.h"
//#import <CoreFoundation/CoreFoundation.h>


//#import "WebRTCModule+RTCMediaStream.h"
//#import "WebRTCModule+RTCPeerConnection.h"

@implementation NetworkConnectionReceiver

//const int BANDWIDTH_2G = 150;
//const int BANDWIDTH_3G = 750;
//const int BANDWIDTH_LTE = 1024; // 1/5
//const int BANDWIDTH_WIFI = 2048;

// network signal 2 = -113
// network signal 3 = -96
// network signal 4 = -94


-(NSString *) getConnectivityTypeFromReachability:(Reachability *)currentReachability andRadioAccessTechnology:(NSString *)radioAccessTechnology
{
    NSString *networkTypeString = @"Unknown";
    NetworkStatus status = [currentReachability currentReachabilityStatus];

    if(status == NotReachable)
    {
        //No internet
        networkTypeString = @"NO NETWORK";
    }
    else if (status == ReachableViaWiFi)
    {
        //WiFi
        networkTypeString = @"WIFI";
    }
    else if (status == ReachableViaWWAN)
    {
        
        
        //3G
        if ([radioAccessTechnology isEqualToString:CTRadioAccessTechnologyGPRS]) {
            networkTypeString = @"2G";
        }
        else if ([radioAccessTechnology isEqualToString:CTRadioAccessTechnologyEdge]) {
            networkTypeString = @"2G";
        }
        else if ([radioAccessTechnology isEqualToString:CTRadioAccessTechnologyWCDMA]) {
            networkTypeString = @"2G";
        }
        else if ([radioAccessTechnology isEqualToString:CTRadioAccessTechnologyCDMA1x]) {
            networkTypeString = @"2G";
        }
        else if ([radioAccessTechnology isEqualToString:CTRadioAccessTechnologyCDMAEVDORev0]) {
            networkTypeString = @"3G";
        }
        else if ([radioAccessTechnology isEqualToString:CTRadioAccessTechnologyCDMAEVDORevA]) {
            networkTypeString = @"3G";
        }
        else if ([radioAccessTechnology isEqualToString:CTRadioAccessTechnologyHSDPA]) {
            networkTypeString = @"3G";
        }
        else if ([radioAccessTechnology isEqualToString:CTRadioAccessTechnologyHSUPA]) {
            networkTypeString = @"3G";
        }
        else if ([radioAccessTechnology isEqualToString:CTRadioAccessTechnologyCDMAEVDORevB]) {
            networkTypeString = @"3G";
        }
        else if ([radioAccessTechnology isEqualToString:CTRadioAccessTechnologyeHRPD]) {
            networkTypeString = @"3G";
        }
        else if ([radioAccessTechnology isEqualToString:CTRadioAccessTechnologyLTE]) {
            networkTypeString = @"LTE";
        }
        else {
            networkTypeString = @"Unknown";
        }
    }
    
    return networkTypeString;
}

-(NSString *)getConnectivityType
{
    NSLog(@"NetworkConnectionReceiver - getConnectivityType method...");
    
    NSString *networkTypeString = @"Unknown";
    
    Reachability *currentReachability = [Reachability reachabilityForInternetConnection];
    NetworkStatus status = [currentReachability currentReachabilityStatus];
    
    CTTelephonyNetworkInfo *telephonyInfo = [CTTelephonyNetworkInfo new];
    NSString *radioAccessTechnology = telephonyInfo.currentRadioAccessTechnology;
    
    NSLog(@"status == %i", status);
    
    if(status == NotReachable)
    {
        //No internet
        networkTypeString = @"NO NETWORK";
    }
    else if (status == ReachableViaWiFi)
    {
        //WiFi
        networkTypeString = @"WIFI";
    }
    else if (status == ReachableViaWWAN)
    {
        //3G
        if ([radioAccessTechnology isEqualToString:CTRadioAccessTechnologyGPRS]) {
            networkTypeString = @"2G";
        }
        else if ([radioAccessTechnology isEqualToString:CTRadioAccessTechnologyEdge]) {
            networkTypeString = @"2G";
        }
        else if ([radioAccessTechnology isEqualToString:CTRadioAccessTechnologyWCDMA]) {
            networkTypeString = @"2G";
        }
        else if ([radioAccessTechnology isEqualToString:CTRadioAccessTechnologyCDMA1x]) {
            networkTypeString = @"2G";
        }
        else if ([radioAccessTechnology isEqualToString:CTRadioAccessTechnologyCDMAEVDORev0]) {
            networkTypeString = @"3G";
        }
        else if ([radioAccessTechnology isEqualToString:CTRadioAccessTechnologyCDMAEVDORevA]) {
            networkTypeString = @"3G";
        }
        else if ([radioAccessTechnology isEqualToString:CTRadioAccessTechnologyHSDPA]) {
            networkTypeString = @"3G";
        }
        else if ([radioAccessTechnology isEqualToString:CTRadioAccessTechnologyHSUPA]) {
            networkTypeString = @"3G";
        }
        else if ([radioAccessTechnology isEqualToString:CTRadioAccessTechnologyCDMAEVDORevB]) {
            networkTypeString = @"3G";
        }
        else if ([radioAccessTechnology isEqualToString:CTRadioAccessTechnologyeHRPD]) {
            networkTypeString = @"3G";
        }
        else if ([radioAccessTechnology isEqualToString:CTRadioAccessTechnologyLTE]) {
            networkTypeString = @"LTE";
        }
        else {
            networkTypeString = @"Unknown";
        }

    } else {
        networkTypeString = @"Unknown";
    }
    
    NSLog(@"networkTypeString = %@",networkTypeString);
    return networkTypeString;
}

//-(void)checkNetworkSignal
//{
//    UIApplication *app = [UIApplication sharedApplication];
//    
//    NSArray *subviews = [[[app valueForKey:@"statusBar"] valueForKey:@"foregroundView"] subviews];
//    NSString *dataNetworkItemView = nil;
//    
//    for (id subview in subviews) {
//        if([subview isKindOfClass:[NSClassFromString(@"UIStatusBarSignalStrengthItemView") class]]) {
//            dataNetworkItemView = subview;
//            break;
//        }
//    }
//    
//    int signalStrength = [[dataNetworkItemView valueForKey:@"signalStrengthRaw"] intValue];
//    NSLog(@"signal %d", signalStrength);
//}

//-(int) getBandwidthValueFromReachability:(Reachability *)currentReachability
//{
//    int bandWidth = 0;
//    CTTelephonyNetworkInfo *telephonyInfo = [CTTelephonyNetworkInfo new];
//    NSString *radioAccessTechnology = telephonyInfo.currentRadioAccessTechnology;
//    NSString *networkTypeString = [self getConnectivityTypeFromReachability:currentReachability andRadioAccessTechnology:radioAccessTechnology];
//    
//    if ([networkTypeString isEqualToString:@"2G"]) {
//        bandWidth = BANDWIDTH_2G;
//    }
//    else if ([networkTypeString isEqualToString:@"3G"]) {
//        bandWidth = BANDWIDTH_3G;
//    }
//    else if ([networkTypeString isEqualToString:@"LTE"]) {
//        bandWidth = BANDWIDTH_LTE;
//    }
//    else if ([networkTypeString isEqualToString:@"WIFI"]) {
//        bandWidth = BANDWIDTH_WIFI;
//    }
//    else {
//        bandWidth = BANDWIDTH_2G;
//    }
//    
//    return bandWidth;
//}

@end
