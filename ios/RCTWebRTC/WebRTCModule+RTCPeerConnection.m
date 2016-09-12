//
//  WebRTCModule+RTCPeerConnection.m
//
//  Created by one on 2015/9/24.
//  Copyright © 2015 One. All rights reserved.
//

#import <objc/runtime.h>
#import <Foundation/Foundation.h>

#import "RCTLog.h"
#import "RCTUtils.h"
#import "RCTBridge.h"
#import "RCTEventDispatcher.h"

#import "RTCICEServer.h"
#import "RTCPair.h"
#import "RTCMediaConstraints.h"
#import "RTCPeerConnection+Block.h"
#import "RTCICECandidate.h"
#import "RTCStatsReport.h"

#import "WebRTCModule+RTCMediaStream.h"
#import "WebRTCModule+RTCPeerConnection.h"
#import "NetworkConnectionReceiver.h"

#import "RCTViewManager.h"
#import <CoreFoundation/CoreFoundation.h>


// CTIndicators API headers
#include "CTCall.h"
#include "CTTelephonyCenter.h"
#include "CTSetting.h"
#include "CTIndicators.h"
#include "CTCellularDataPlan.h"
#include "CTSIMSupport.h"
#include "CTRegistration.h"
#include "CTServerConnection.h"


// MobileWifi.framework
//#include <math.h>
//#include "MobileWiFi.h"

@implementation RTCPeerConnection (React)

- (NSNumber *)reactTag
{
    return objc_getAssociatedObject(self, _cmd);
}

- (void)setReactTag:(NSNumber *)reactTag
{
    objc_setAssociatedObject(self, @selector(reactTag), reactTag, OBJC_ASSOCIATION_COPY_NONATOMIC);
}

@end

@implementation WebRTCModule (RTCPeerConnection)

RCT_EXPORT_MODULE();
RCT_EXPORT_VIEW_PROPERTY(onConnectionTypeChanged, RCTBubblingEventBlock);

NSString *localSdp;
NSString *remoteSdp;
NSString *localSdpType;
NSString *remoteSdpType;
NSString *REMOTE_SDP_TYPE;

//NSArray *localSdpArray;
//NSArray *remoteSdpArray;
NSTimer *timer;

const int MAX_NETWORK_BAR_STRENGTH = 5;
const int MAX_WIFI_BAR_STRENGTH = 3;
const int BANDWIDTH_2G = 150;
const int BANDWIDTH_3G = 750;
const int BANDWIDTH_LTE = 1024;
const int BANDWIDTH_WIFI = 2048;

int previousBandwidthValue;
int previousCellularSignalStrength;
int previousWifiSignalStrength;
NSString *connectivityType;

RCT_EXPORT_METHOD(peerConnectionInit:(NSDictionary *)configuration objectID:(nonnull NSNumber *)objectID)
{
    NSArray *iceServers = [self createIceServers:configuration[@"iceServers"]];
    
    RTCPeerConnection *peerConnection = [self.peerConnectionFactory peerConnectionWithICEServers:iceServers constraints:[self defaultPeerConnectionConstraints] delegate:self];
    peerConnection.reactTag = objectID;
    self.peerConnections[objectID] = peerConnection;
}

RCT_EXPORT_METHOD(peerConnectionAddStream:(nonnull NSNumber *)streamID objectID:(nonnull NSNumber *)objectID)
{
    RTCMediaStream *stream = self.mediaStreams[streamID];
    if (!stream) {
        return;
    }
    RTCPeerConnection *peerConnection = self.peerConnections[objectID];
    if (!peerConnection) {
        return;
    }
    BOOL result = [peerConnection addStream:stream];
    NSLog(@"result:%i", result);
}

RCT_EXPORT_METHOD(peerConnectionRemoveStream:(nonnull NSNumber *)streamID objectID:(nonnull NSNumber *)objectID)
{
    RTCMediaStream *stream = self.mediaStreams[streamID];
    if (!stream) {
        return;
    }
    RTCPeerConnection *peerConnection = self.peerConnections[objectID];
    if (!peerConnection) {
        return;
    }
    [peerConnection removeStream:stream];
}


RCT_EXPORT_METHOD(peerConnectionCreateOffer:(nonnull NSNumber *)objectID callback:(RCTResponseSenderBlock)callback)
{
    RTCPeerConnection *peerConnection = self.peerConnections[objectID];
    if (!peerConnection) {
        return;
    }
    
    [peerConnection createOfferWithCallback:^(RTCSessionDescription *sdp, NSError *error) {
        if (error) {
            callback(@[@(NO),
                       @{@"type": @"CreateOfferFailed", @"message": error.userInfo[@"error"]}
                       ]);
        } else {
            callback(@[@(YES), @{@"sdp": sdp.description, @"type": sdp.type}]);
        }
        
    } constraints:nil];
}

- (RTCMediaConstraints *)defaultAnswerConstraints {
    return [self defaultOfferConstraints];
}

- (RTCMediaConstraints *)defaultOfferConstraints {
    NSArray *mandatoryConstraints = @[
                                      [[RTCPair alloc] initWithKey:@"OfferToReceiveAudio" value:@"true"],
                                      [[RTCPair alloc] initWithKey:@"OfferToReceiveVideo" value:@"true"]
                                      ];
    RTCMediaConstraints* constraints =
    [[RTCMediaConstraints alloc]
     initWithMandatoryConstraints:mandatoryConstraints
     optionalConstraints:nil];
    return constraints;
}

- (RTCMediaConstraints *)defaultPeerConnectionConstraints {
    NSArray *optionalConstraints = @[
                                     [[RTCPair alloc] initWithKey:@"DtlsSrtpKeyAgreement" value:@"true"]
                                     ];
    RTCMediaConstraints* constraints =
    [[RTCMediaConstraints alloc]
     initWithMandatoryConstraints:nil
     optionalConstraints:optionalConstraints];
    return constraints;
}


RCT_EXPORT_METHOD(peerConnectionCreateAnswer:(nonnull NSNumber *)objectID callback:(RCTResponseSenderBlock)callback)
{
    RTCPeerConnection *peerConnection = self.peerConnections[objectID];
    if (!peerConnection) {
        return;
    }
    
    [peerConnection createAnswerWithCallback:^(RTCSessionDescription *sdp, NSError *error) {
        if (error) {
            callback(@[@(NO),
                       @{@"type": @"CreateAnsweFailed", @"message": error.userInfo[@"error"]}
                       ]);
        } else {
            callback(@[@(YES), @{@"sdp": sdp.description, @"type": sdp.type}]);
            //remoteSdp = sdp.description;
        }
        
    } constraints:[self defaultAnswerConstraints]];
}

RCT_EXPORT_METHOD(peerConnectionSetLocalDescription:(NSDictionary *)sdpJSON objectID:(nonnull NSNumber *)objectID callback:(RCTResponseSenderBlock)callback)
{
    RTCSessionDescription *sdp = [[RTCSessionDescription alloc] initWithType:sdpJSON[@"type"] sdp:sdpJSON[@"sdp"]];
    RTCPeerConnection *peerConnection = self.peerConnections[objectID];
    if (!peerConnection) {
        return;
    }
    localSdp = sdp.description;
    localSdpType = sdp.type;
    
    //    if (localSdpArray.count > 0) {
    //        [localSdpArray removeal];
    //    }
    
    //    if ([localSdp containsString:@"m=video"]) {
    //        localSdpArray = [localSdp componentsSeparatedByString:@"\n"];
    ////        for (NSString *aString in localSdpArray) {
    ////            NSLog(@"--------- %@",aString);
    ////        }
    //    }
    
    [peerConnection setLocalDescriptionWithCallback:^(NSError *error) {
        if (error) {
            id errorResponse = @{@"name": @"SetLocalDescriptionFailed",
                                 @"message": error.localizedDescription};
            callback(@[@(NO), errorResponse]);
        } else {
            callback(@[@(YES)]);
        }
    } sessionDescription:sdp];
}

RCT_EXPORT_METHOD(peerConnectionSetRemoteDescription:(NSDictionary *)sdpJSON objectID:(nonnull NSNumber *)objectID callback:(RCTResponseSenderBlock)callback)
{
    RTCSessionDescription *sdp = [[RTCSessionDescription alloc] initWithType:sdpJSON[@"type"] sdp:sdpJSON[@"sdp"]];
    remoteSdp = sdp.description;
    remoteSdpType = sdp.type;
    REMOTE_SDP_TYPE = sdp.type;
    
    //    if (remoteSdpArray.count > 0) {
    //        [remoteSdpArray removeAllObjects];
    //    }
    
    //    if ([remoteSdp containsString:@"m=video"]) {
    //        remoteSdpArray = [remoteSdp componentsSeparatedByString:@"\n"];
    //        for (NSString *aString in remoteSdpArray) {
    //            NSLog(@"--------- %@",aString);
    //        }
    //    }
    
    RTCPeerConnection *peerConnection = self.peerConnections[objectID];
    if (!peerConnection) {
        return;
    }
    
    [peerConnection setRemoteDescriptionWithCallback:^(NSError *error) {
        if (error) {
            id errorResponse = @{@"name": @"SetRemoteDescriptionFailed",
                                 @"message": error.localizedDescription};
            callback(@[@(NO), errorResponse]);
        } else {
            callback(@[@(YES)]);
        }
    } sessionDescription:sdp];
}

RCT_EXPORT_METHOD(peerConnectionAddICECandidate:(NSDictionary*)candidateJSON objectID:(nonnull NSNumber *)objectID callback:(RCTResponseSenderBlock)callback)
{
    RTCICECandidate *candidate = [[RTCICECandidate alloc] initWithMid:candidateJSON[@"sdpMid"] index:[candidateJSON[@"sdpMLineIndex"] integerValue] sdp:candidateJSON[@"candidate"]];
    RTCPeerConnection *peerConnection = self.peerConnections[objectID];
    if (!peerConnection) {
        return;
    }
    
    BOOL result = [peerConnection addICECandidate:candidate];
    NSLog(@"addICECandidateresult:%i, %@", result, candidate);
    callback(@[@(result)]);
    
    NSError *error;
    [[AVAudioSession sharedInstance] overrideOutputAudioPort:AVAudioSessionPortOverrideSpeaker error:&error];
}

RCT_EXPORT_METHOD(peerConnectionClose:(nonnull NSNumber *)objectID)
{
    RTCPeerConnection *peerConnection = self.peerConnections[objectID];
    if (!peerConnection) {
        return;
    }
    
    [peerConnection close];
    [self.peerConnections removeObjectForKey:objectID];
}

RCT_EXPORT_METHOD(peerConnectionGetStats:(nonnull NSNumber *)trackID objectID:(nonnull NSNumber *)objectID callback:(RCTResponseSenderBlock)callback)
{
    RTCMediaStreamTrack *track = nil;
    if ([trackID integerValue] >= 0) {
        track = self.tracks[trackID];
    }
    
    RTCPeerConnection *peerConnection = self.peerConnections[objectID];
    if (!peerConnection) {
        return;
    }
    
    BOOL result = [peerConnection getStatsWithCallback:^(NSArray *stats) {
        NSMutableArray *statsCollection = [NSMutableArray new];
        for (RTCStatsReport *statsReport in stats) {
            NSMutableArray *valuesCollection = [NSMutableArray new];
            for (RTCPair *pair in statsReport.values) {
                [valuesCollection addObject:@{pair.key: pair.value}];
            }
            [statsCollection addObject:@{
                                         @"id": statsReport.reportId,
                                         @"type": statsReport.type,
                                         @"timestamp": @(statsReport.timestamp),
                                         @"values": valuesCollection,
                                         }];
        }
        callback(@[statsCollection]);
        //    NSLog(@"getStatsWithCallback: %@, %@", streamID, stats);
    } mediaStreamTrack:track statsOutputLevel:RTCStatsOutputLevelStandard];
    NSLog(@"getStatsResult: %i", result);
}

- (NSArray*)createIceServers:(NSArray*)iceServersConfiguration {
    NSMutableArray *iceServers = [NSMutableArray new];
    if (iceServersConfiguration) {
        for (NSDictionary *iceServerConfiguration in iceServersConfiguration) {
            NSString *username = iceServerConfiguration[@"username"];
            if (!username) {
                username = @"";
            }
            NSString *credential = iceServerConfiguration[@"credential"];
            if (!credential) {
                credential = @"";
            }
            
            if (iceServerConfiguration[@"url"]) {
                NSString *url = iceServerConfiguration[@"url"];
                
                RTCICEServer *iceServer = [[RTCICEServer alloc] initWithURI:[NSURL URLWithString:url] username:username password:credential];
                [iceServers addObject:iceServer];
            } else if (iceServerConfiguration[@"urls"]) {
                if ([iceServerConfiguration[@"urls"] isKindOfClass:[NSString class]]) {
                    NSString *url = iceServerConfiguration[@"urls"];
                    
                    RTCICEServer *iceServer = [[RTCICEServer alloc] initWithURI:[NSURL URLWithString:url] username:username password:credential];
                    [iceServers addObject:iceServer];
                } else if ([iceServerConfiguration[@"urls"] isKindOfClass:[NSArray class]]) {
                    NSArray *urls = iceServerConfiguration[@"urls"];
                    for (NSString *url in urls) {
                        RTCICEServer *iceServer = [[RTCICEServer alloc] initWithURI:[NSURL URLWithString:url] username:username password:credential];
                        [iceServers addObject:iceServer];
                    }
                }
            }
        }
    }
    return iceServers;
}

- (NSString *)stringForICEConnectionState:(RTCICEConnectionState)state {
    switch (state) {
        case RTCICEConnectionNew: return @"new";
        case RTCICEConnectionChecking: return @"checking";
        case RTCICEConnectionConnected: return @"connected";
        case RTCICEConnectionCompleted: return @"completed";
        case RTCICEConnectionFailed: return @"failed";
        case RTCICEConnectionDisconnected: return @"disconnected";
        case RTCICEConnectionClosed: return @"closed";
    }
    return nil;
}

- (NSString *)stringForICEGatheringState:(RTCICEGatheringState)state {
    switch (state) {
        case RTCICEGatheringNew: return @"new";
        case RTCICEGatheringGathering: return @"gathering";
        case RTCICEGatheringComplete: return @"complete";
    }
    return nil;
}

- (NSString *)stringForSignalingState:(RTCSignalingState)state {
    switch (state) {
        case RTCSignalingStable: return @"stable";
        case RTCSignalingHaveLocalOffer: return @"have-local-offer";
        case RTCSignalingHaveLocalPrAnswer: return @"have-local-pranswer";
        case RTCSignalingHaveRemoteOffer: return @"have-remote-offer";
        case RTCSignalingHaveRemotePrAnswer: return @"have-remote-pranswer";
        case RTCSignalingClosed: return @"closed";
    }
    return nil;
}

#pragma mark - RTCPeerConnectionDelegate methods

- (void)peerConnection:(RTCPeerConnection *)peerConnection signalingStateChanged:(RTCSignalingState)newState {
    [self.bridge.eventDispatcher sendDeviceEventWithName:@"peerConnectionSignalingStateChanged" body:
     @{@"id": peerConnection.reactTag, @"signalingState": [self stringForSignalingState:newState]}];
}

- (void)peerConnection:(RTCPeerConnection *)peerConnection addedStream:(RTCMediaStream *)stream {
    NSNumber *objectID = @(self.mediaStreamId++);
    
    NSLog(@"peerConnection addedStream method...");
    
    stream.reactTag = objectID;
    NSMutableArray *tracks = [NSMutableArray array];
    for (RTCVideoTrack *track in stream.videoTracks) {
        NSNumber *trackId = @(self.trackId++);
        track.reactTag = trackId;
        self.tracks[trackId] = track;
        [tracks addObject:@{@"id": trackId, @"kind": track.kind, @"label": track.label, @"enabled": @(track.isEnabled), @"remote": @(YES), @"readyState": @"live"}];
    }
    for (RTCAudioTrack *track in stream.audioTracks) {
        NSNumber *trackId = @(self.trackId++);
        track.reactTag = trackId;
        self.tracks[trackId] = track;
        [tracks addObject:@{@"id": trackId, @"kind": track.kind, @"label": track.label, @"enabled": @(track.isEnabled), @"remote": @(YES), @"readyState": @"live"}];
    }
    
    self.mediaStreams[objectID] = stream;
    [self.bridge.eventDispatcher sendDeviceEventWithName:@"peerConnectionAddedStream" body:
     @{@"id": peerConnection.reactTag, @"streamId": stream.reactTag, @"tracks": tracks}];
}

- (void)peerConnection:(RTCPeerConnection *)peerConnection removedStream:(RTCMediaStream *)stream {
    // TODO: remove stream from self.mediaStreams
    if (self.mediaStreams[stream.reactTag]) {
        
        RTCMediaStream *mediaStream = self.mediaStreams[stream.reactTag];
        for (RTCVideoTrack *track in mediaStream.videoTracks) {
            [self.tracks removeObjectForKey:track.reactTag];
        }
        for (RTCAudioTrack *track in mediaStream.audioTracks) {
            [self.tracks removeObjectForKey:track.reactTag];
        }
        [self.mediaStreams removeObjectForKey:stream.reactTag];
    }
    [self.bridge.eventDispatcher sendDeviceEventWithName:@"peerConnectionRemovedStream" body:
     @{@"id": peerConnection.reactTag, @"streamId": stream.reactTag}];
}

- (void)peerConnectionOnRenegotiationNeeded:(RTCPeerConnection *)peerConnection {
    [self.bridge.eventDispatcher sendDeviceEventWithName:@"peerConnectionOnRenegotiationNeeded" body:
     @{@"id": peerConnection.reactTag}];
}

- (void)peerConnection:(RTCPeerConnection *)peerConnection iceConnectionChanged:(RTCICEConnectionState)newState {
    [self.bridge.eventDispatcher sendDeviceEventWithName:@"peerConnectionIceConnectionChanged" body:
     @{@"id": peerConnection.reactTag, @"iceConnectionState": [self stringForICEConnectionState:newState]}];
}

- (void)peerConnection:(RTCPeerConnection *)peerConnection iceGatheringChanged:(RTCICEGatheringState)newState {
    [self.bridge.eventDispatcher sendDeviceEventWithName:@"peerConnectionIceGatheringChanged" body:
     @{@"id": peerConnection.reactTag, @"iceGatheringState": [self stringForICEGatheringState:newState]}];
}

- (void)peerConnection:(RTCPeerConnection *)peerConnection gotICECandidate:(RTCICECandidate *)candidate {
    [self.bridge.eventDispatcher sendDeviceEventWithName:@"peerConnectionGotICECandidate" body:
     @{@"id": peerConnection.reactTag, @"candidate": @{@"candidate": candidate.sdp, @"sdpMLineIndex": @(candidate.sdpMLineIndex), @"sdpMid": candidate.sdpMid}}];
}

- (void)peerConnection:(RTCPeerConnection*)peerConnection didOpenDataChannel:(RTCDataChannel*)dataChannel {
    
}


// PRAGMA MARK: - Video Adjustment -

//WebRTCModule *thisInstance;

//RCT_EXPORT_METHOD(startObservingNetworkSignalStrength)
//{
////    thisInstance = self;
////
////    CTTelephonyCenterAddObserver(CTTelephonyCenterGetDefault(), NULL, SignalStrengthDidChange, kCTIndicatorsSignalStrengthNotification, NULL, CFNotificationSuspensionBehaviorCoalesce);
////
//////    dispatch_async (dispatch_get_main_queue(), ^{
//////        CFRunLoopRun();
//////    });
////
////    CFRunLoopRun();
//
//}
//
//RCT_EXPORT_METHOD(removeObservingNetworkSignalStrength)
//{
////    CTTelephonyCenterRemoveEveryObserver(CTTelephonyCenterGetDefault(), NULL);
//}

//void SignalStrengthDidChange(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo)
//{
//    long int raw = 0;
//    long int graded = 0;
//    long int bars = 0;
//
//    CTIndicatorsGetSignalStrength(&raw, &graded, &bars);
//
//    printf("Signal strength changed! Raw: %li, graded: %li bars: %li\n", raw, graded, bars);
//    // Prints something like:
//    // Signal strength changed! Raw: -96, graded: 27 bars: 3
//
//    //[thisInstance changeBandWidthByBars:bars];
//}

//RCT_EXPORT_METHOD(startConnectivityMonitoring)
//{
//    // 1. check wether connection type is Wifi or not
//    NetworkConnectionReceiver *ncr = [[NetworkConnectionReceiver alloc] init];
//    NSString *connectivityType = [ncr getConnectivityType];
//
//    if ([connectivityType isEqualToString:@"WIFI"]) {
//        [self startTimerForCellularSignalStrengthMonitoring];
//    } else {
//
//    }
//}


RCT_EXPORT_METHOD(startConnectivityMonitoring)
{
    NSLog(@"startConnectivityMonitoring method...");
    
    [self registerForConnectivityChangeEventNotification];
    
    timer = [NSTimer scheduledTimerWithTimeInterval: 5.0
                                             target: self
                                           selector:@selector(getConnectivityType)
                                           userInfo: nil repeats:YES];
    
}

RCT_EXPORT_METHOD(stopConnectivityMonitoring)
{
    NSLog(@"stopConnectivityMonitoring method...");
    
    if (timer != nil) {
        [timer invalidate];
        timer = nil;
    }
}

-(void)getConnectivityType
{
    NSLog(@"getConnectivityType method...");
    
    NetworkConnectionReceiver *ncr = [[NetworkConnectionReceiver alloc] init];
    connectivityType = [ncr getConnectivityType];
    
    if ([connectivityType isEqualToString:@"WIFI"]) {
        [self setSdpWithNewBandwidthValue:BANDWIDTH_WIFI];
        //[self getWifiSignalStrength];
    }
    else if ([connectivityType isEqualToString:@"NO NETWORK"] || [connectivityType isEqualToString:@"Unknown"]){
        // do nothing here
    }
    else {
        [self getCellularSignalStrength];
    }
}

-(void)getCellularSignalStrength
{
    NSLog(@"getCellularSignalStrength method...");
    
    UIApplication *app = [UIApplication sharedApplication];
    NSArray *subviews = [[[app valueForKey:@"statusBar"] valueForKey:@"foregroundView"] subviews];
    NSString *dataNetworkItemView = nil;
    
    for (id subview in subviews) {
        if([subview isKindOfClass:[NSClassFromString(@"UIStatusBarSignalStrengthItemView") class]]) {
            dataNetworkItemView = subview;
            break;
        }
    }
    
    int currentSignalStrength = [[dataNetworkItemView valueForKey:@"signalStrengthBars"] intValue];
    NSLog(@"signal bar = %d", currentSignalStrength);
    
    if (previousCellularSignalStrength != currentSignalStrength) {
        [self changeBandWidthValueWithNewSignalStrength:currentSignalStrength];
        previousCellularSignalStrength = currentSignalStrength;
    }
}

-(void)getWifiSignalStrength
{
    //    WiFiManagerRef manager = WiFiManagerClientCreate(kCFAllocatorDefault, 0);
    //    CFArrayRef devices = WiFiManagerClientCopyDevices(manager);
    //
    //    WiFiDeviceClientRef client = (WiFiDeviceClientRef)CFArrayGetValueAtIndex(devices, 0);
    //    CFDictionaryRef data = (CFDictionaryRef)WiFiDeviceClientCopyProperty(client, CFSTR("RSSI"));
    //    CFNumberRef scaled = (CFNumberRef)WiFiDeviceClientCopyProperty(client, kWiFiScaledRSSIKey);
    //
    //    CFNumberRef RSSI = (CFNumberRef)CFDictionaryGetValue(data, CFSTR("RSSI_CTL_AGR"));
    //
    //    int raw;
    //    CFNumberGetValue(RSSI, kCFNumberIntType, &raw);
    //
    //    float strength;
    //    CFNumberGetValue(scaled, kCFNumberFloatType, &strength);
    //    CFRelease(scaled);
    //
    //    strength *= -1;
    //
    //    // Apple uses -3.0.
    //    int currentWifiSignalStrength = (int)ceilf(strength * -3.0f);
    //    currentWifiSignalStrength = MAX(1, MIN(currentWifiSignalStrength, 3));
    //
    //    printf("WiFi signal strength: %d dBm\n\t Bars: %d\n", raw,  currentWifiSignalStrength);
    //
    //    if (previousWifiSignalStrength != currentWifiSignalStrength) {
    //        [self changeBandWidthValueWithNewSignalStrength:currentWifiSignalStrength];
    //        previousWifiSignalStrength = currentWifiSignalStrength;
    //    }
    //
    //    CFRelease(data);
    //    CFRelease(scaled);
    //    CFRelease(devices);
    //    CFRelease(manager);
}

-(void) changeBandWidthValueWithNewSignalStrength:(int) signalStrength
{
    int newBandwidthValue = 0;
    int bandWidthSize = 0;
    int maxBarStrength = 0;
    
    if ([connectivityType isEqualToString:@"2G"]){
        bandWidthSize = BANDWIDTH_2G;
        maxBarStrength = MAX_NETWORK_BAR_STRENGTH;
    }
    else if ([connectivityType isEqualToString:@"3G"]){
        bandWidthSize = BANDWIDTH_3G;
        maxBarStrength = MAX_NETWORK_BAR_STRENGTH;
    }
    else if ([connectivityType isEqualToString:@"LTE"]){
        bandWidthSize = BANDWIDTH_LTE;
        maxBarStrength = MAX_NETWORK_BAR_STRENGTH;
    }
    else if ([connectivityType isEqualToString:@"WIFI"]){
        bandWidthSize = BANDWIDTH_WIFI;
        maxBarStrength = MAX_WIFI_BAR_STRENGTH;
    }
    
    newBandwidthValue = bandWidthSize * signalStrength / maxBarStrength;
    if ( newBandwidthValue != 0 )
    {
        [self setSdpWithNewBandwidthValue:newBandwidthValue];
    }
}

-(void)setSdpWithNewBandwidthValue:(int)newBandwidth
{
    NSLog(@"setSdpWithNewBandwidthValue method...");
    
    [self setBandwidthSize:newBandwidth fromAnSdpString:localSdp withTheSdpType:localSdpType withOptionalCompletionBlock:^{
        
        [self setBandwidthSize:newBandwidth fromAnSdpString:remoteSdp withTheSdpType:remoteSdpType withOptionalCompletionBlock:^{
            
            previousBandwidthValue = newBandwidth;
        }];
    }];
}

-(void)setBandwidthSize:(int)bandwidth fromAnSdpString:(NSString *)sdpString withTheSdpType:(NSString *)sdpType withOptionalCompletionBlock:(void (^)(void))completionBlock
{
    NSLog(@"setBandwidthSizeFromAnSdpArray method...");
    
    NSMutableArray *newSdpArray = [[NSMutableArray alloc] init];
    
    if ([localSdp containsString:@"m=video"]) {
        newSdpArray = [localSdp componentsSeparatedByString:@"\n"];
    }
    
    int indexToInsert1 = 0;
    
    for (int i = 0 ; i < newSdpArray.count - 1 ; i++) {
        NSString *aString = newSdpArray[i];
        if ([aString containsString:@"m=video"]) {
            indexToInsert1 = i + 2;
            break;
        }
    }
    int indexToInsert2 = indexToInsert1 + 1;
    int indexToInsert3 = indexToInsert2 + 1;
    
    // insert the bandwidthValue
    NSString *stringToInsert1 = [[NSString alloc] initWithFormat:@"b=AS:%i\n",bandwidth];
    NSString *stringToInsert2 = [[NSString alloc] initWithFormat:@"b=RS:%i\n",bandwidth];
    NSString *stringToInsert3 = [[NSString alloc] initWithFormat:@"b=RR:%i\n",bandwidth];
    
    [newSdpArray insertObject:stringToInsert1 atIndex:indexToInsert1];
    [newSdpArray insertObject:stringToInsert2 atIndex:indexToInsert2];
    [newSdpArray insertObject:stringToInsert3 atIndex:indexToInsert3];
    NSString *newSdpString = @"";
    for (NSString *desc in newSdpArray) {
        NSString *stringToAppend = [NSString stringWithFormat:@"%@\n",desc];
        newSdpString = [newSdpString stringByAppendingString:stringToAppend];
    }
    
    NSLog(@"new %@ string = %@",sdpType ,newSdpString);
    
    // reconstruct the localSdpDescription
    RTCPeerConnection *peerConnection = [self.peerConnections objectForKey:0];
    RTCSessionDescription *newSdp = [[RTCSessionDescription alloc] initWithType:sdpType sdp:newSdpString];
    
    if ([sdpType isEqualToString:REMOTE_SDP_TYPE]) {
        [peerConnection setRemoteDescriptionWithCallback:nil sessionDescription:newSdp];
        completionBlock();
    } else {
        [peerConnection setLocalDescriptionWithCallback:nil sessionDescription:newSdp];
        completionBlock();
    }
}

-(void) registerForConnectivityChangeEventNotification
{
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(reachabilityChanged:) name:kReachabilityChangedNotification object:nil];
}

- (void) reachabilityChanged:(NSNotification *)notification
{
    NSLog(@"reachabilityChanged method...");
    
    [self getConnectivityType];
}

-(void) endTheCall
{
    if (!self.onConnectionTypeChanged) {
        return;
    }
    
    BOOL hasChanged = YES;
    self.onConnectionTypeChanged(@{
                                   @"connectionStatus": @{
                                           @"connectionHasChanged": @(hasChanged),
                                           }
                                   });
}

-(void) endTheCallEvent
{
    NSString *eventName = @"endTheCallEvent";
    
    [self.bridge.eventDispatcher sendDeviceEventWithName:@"connectionTypeChangedEvent" body:
     @{@"name": eventName}];
}


// PRAGMA MARK: - Wifi Connection -

//RCT_EXPORT_METHOD(getWifiSignalStrength)
//{
//    WiFiManagerRef manager = WiFiManagerClientCreate(kCFAllocatorDefault, 0);
//    CFArrayRef devices = WiFiManagerClientCopyDevices(manager);
//    
//    WiFiDeviceClientRef client = (WiFiDeviceClientRef)CFArrayGetValueAtIndex(devices, 0);
//    CFDictionaryRef data = (CFDictionaryRef)WiFiDeviceClientCopyProperty(client, CFSTR("RSSI"));
//    CFNumberRef scaled = (CFNumberRef)WiFiDeviceClientCopyProperty(client, kWiFiScaledRSSIKey);
//    
//    CFNumberRef RSSI = (CFNumberRef)CFDictionaryGetValue(data, CFSTR("RSSI_CTL_AGR"));
//    
//    int raw;
//    CFNumberGetValue(RSSI, kCFNumberIntType, &raw);
//    
//    float strength;
//    CFNumberGetValue(scaled, kCFNumberFloatType, &strength);
//    CFRelease(scaled);
//    
//    strength *= -1;
//    
//    // Apple uses -3.0.
//    int bars = (int)ceilf(strength * -3.0f);
//    bars = MAX(1, MIN(bars, 3));
//    
//    
//    printf("WiFi signal strength: %d dBm\n\t Bars: %d\n", raw,  bars);
//    
//    CFRelease(data);
//    CFRelease(scaled);
//    CFRelease(devices);
//    CFRelease(manager);
//}


@end
