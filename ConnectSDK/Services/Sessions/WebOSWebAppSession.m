//
//  WebOSWebAppSession.m
//  Connect SDK
//
//  Created by Jeremy White on 2/23/14.
//  Copyright (c) 2014 LG Electronics.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

#import "WebOSWebAppSession.h"
#import "ConnectError.h"


@implementation WebOSWebAppSession
{
    ServiceSubscription *_playStateSubscription;
    ServiceSubscription *_messageSubscription;
    NSMutableDictionary *_activeCommands;

    int _UID;
    BOOL _connected;
}

- (instancetype)initWithLaunchSession:(LaunchSession *)launchSession service:(DeviceService *)service
{
    self = [super initWithLaunchSession:launchSession service:service];

    if (self)
    {
        _UID = 0;
        _activeCommands = [NSMutableDictionary new];
        _connected = NO;

        __weak id weakSelf = self;

        _messageHandler = ^(id message)
        {
            if ([message isKindOfClass:[NSDictionary class]])
            {
                NSDictionary *messageJSON = (NSDictionary *)message;

                NSString *contentType = [messageJSON objectForKey:@"contentType"];
                NSRange contentTypeRange = [contentType rangeOfString:@"connectsdk."];

                if (contentType && contentTypeRange.location != NSNotFound)
                {
                    NSString *payloadKey = [contentType substringFromIndex:contentTypeRange.length];

                    if (!payloadKey || payloadKey.length == 0)
                        return;

                    id payload = [messageJSON objectForKey:payloadKey];

                    if (!payload)
                        return;

                    if ([payloadKey isEqualToString:@"mediaEvent"])
                        [weakSelf handleMediaEvent:payload];
                    else if ([payloadKey isEqualToString:@"mediaCommandResponse"])
                        [weakSelf handleMediaCommandResponse:payload];
                } else
                {
                    [weakSelf handleMessage:messageJSON];
                }
            } else if ([message isKindOfClass:[NSString class]])
            {
                [weakSelf handleMessage:message];
            }
        };
    }

    return self;
}

- (int) getNextId
{
    _UID = _UID + 1;
    return _UID;
}

#pragma mark - Subscription methods

- (int)sendSubscription:(ServiceSubscription *)subscription type:(ServiceSubscriptionType)type payload:(id)payload toURL:(NSURL *)URL withId:(int)callId
{
    if (type == ServiceSubscriptionTypeUnsubscribe)
    {
        if (subscription == _playStateSubscription)
            _playStateSubscription = nil;
        else if (subscription == _messageSubscription)
            _messageSubscription = nil;
    }

    return -1;
}

#pragma mark - Message handlers

- (void) handleMediaEvent:(NSDictionary *)payload
{
    NSString *type = [payload objectForKey:@"type"];

    if ([type isEqualToString:@"playState"])
    {
        if (!_playStateSubscription)
            return;

        NSString *playStateString = [payload objectForKey:@"playState"];
        MediaControlPlayState playState = [self parsePlayState:playStateString];

        [_playStateSubscription.successCalls enumerateObjectsUsingBlock:^(id success, NSUInteger idx, BOOL *stop)
        {
            MediaPlayStateSuccessBlock mediaPlayStateSuccess = (MediaPlayStateSuccessBlock) success;

            if (mediaPlayStateSuccess)
                mediaPlayStateSuccess(playState);
        }];
    }
}

- (void) handleMediaCommandResponse:(NSDictionary *)payload
{
    NSString *requestId = [payload objectForKey:@"requestId"];

    ServiceCommand *command = [_activeCommands objectForKey:requestId];

    if (!command)
        return;

    NSString *error = [payload objectForKey:@"error"];

    if (error)
    {
        if (command.callbackError)
            command.callbackError([ConnectError generateErrorWithCode:ConnectStatusCodeError andDetails:error]);
    } else
    {
        if (command.callbackComplete)
            command.callbackComplete(payload);
    }

    [_activeCommands removeObjectForKey:requestId];
}

- (void) handleMessage:(id)message
{
    if (self.delegate && [self.delegate respondsToSelector:@selector(webAppSession:didReceiveMessage:)])
        [self.delegate webAppSession:self didReceiveMessage:message];
}

- (MediaControlPlayState) parsePlayState:(NSString *)playStateString
{
    MediaControlPlayState playState = MediaControlPlayStateUnknown;

    if ([playStateString isEqualToString:@"playing"])
        playState = MediaControlPlayStatePlaying;
    else if ([playStateString isEqualToString:@"paused"])
        playState = MediaControlPlayStatePaused;
    else if ([playStateString isEqualToString:@"idle"])
        playState = MediaControlPlayStateIdle;
    else if ([playStateString isEqualToString:@"buffering"])
        playState = MediaControlPlayStateBuffering;
    else if ([playStateString isEqualToString:@"finished"])
        playState = MediaControlPlayStateFinished;

    return playState;
}

- (void) connectWithSuccess:(SuccessBlock)success failure:(FailureBlock)failure
{
    if (!_messageSubscription)
        _messageSubscription = [ServiceSubscription subscriptionWithDelegate:nil target:nil payload:nil callId:-1];

    if (_connected)
    {
        if (success)
            success(nil);

        return;
    }

    [self.service connectToWebApp:self success:^(id responseObject)
    {
        _connected = YES;

        if (success)
            success(nil);
    } failure:failure];
}

- (void) joinWithSuccess:(SuccessBlock)success failure:(FailureBlock)failure
{
    [self.service connectToWebApp:self joinOnly:YES success:^(id responseObject)
    {
        _connected = YES;

        if (success)
            success(self);
    } failure:failure];
}

- (void)sendText:(NSString *)message success:(SuccessBlock)success failure:(FailureBlock)failure
{
    if (!message || message.length == 0)
    {
        if (failure)
            failure([ConnectError generateErrorWithCode:ConnectStatusCodeArgumentError andDetails:@"Cannot send a nil message"]);

        return;
    }

    if (_connected)
        [self.service sendMessage:message toApp:self.launchSession success:success failure:failure];
    else
    {
        [self connectWithSuccess:^(id responseObject)
        {
            [self.service sendMessage:message toApp:self.launchSession success:success failure:failure];
        }                failure:failure];
    }
}

- (void)sendJSON:(NSDictionary *)message success:(SuccessBlock)success failure:(FailureBlock)failure
{
    if (!message)
    {
        if (failure)
            failure([ConnectError generateErrorWithCode:ConnectStatusCodeArgumentError andDetails:@"Cannot send a nil message"]);

        return;
    }

    if (_connected)
        [self.service sendMessage:message toApp:self.launchSession success:success failure:failure];
    else
    {
        [self connectWithSuccess:^(id responseObject)
        {
            [self.service sendMessage:message toApp:self.launchSession success:success failure:failure];
        }                failure:failure];
    }
}

- (void) disconnectFromWebApp
{
    [self.service disconnectFromWebApp:self];
}

- (void)closeWithSuccess:(SuccessBlock)success failure:(FailureBlock)failure
{
    _connected = NO;
    _activeCommands = [NSMutableDictionary new];

    [_playStateSubscription unsubscribe];
    _playStateSubscription = nil;

    _messageSubscription = nil;

    [self.service disconnectFromWebApp:self];

    [self.service.webAppLauncher closeWebApp:self.launchSession success:success failure:failure];
}

#pragma mark - Media Player

- (id <MediaPlayer>) mediaPlayer
{
    return self;
}

- (CapabilityPriorityLevel) mediaPlayerPriority
{
    return CapabilityPriorityLevelHigh;
}

- (void) displayImage:(NSURL *)imageURL iconURL:(NSURL *)iconURL title:(NSString *)title description:(NSString *)description mimeType:(NSString *)mimeType success:(MediaPlayerDisplaySuccessBlock)success failure:(FailureBlock)failure
{
    int requestIdNumber = [self getNextId];
    NSString *requestId = [NSString stringWithFormat:@"req%d", requestIdNumber];

    NSDictionary *message = @{
            @"contentType" : @"connectsdk.mediaCommand",
            @"mediaCommand" : @{
                    @"type" : @"displayImage",
                    @"mediaURL" : ensureString(imageURL.absoluteString),
                    @"iconURL" : ensureString(iconURL.absoluteString),
                    @"title" : ensureString(title),
                    @"description" : ensureString(description),
                    @"mimeType" : ensureString(mimeType),
                    @"requestId" : requestId
            }
    };

    ServiceCommand *command = [ServiceCommand commandWithDelegate:nil target:nil payload:nil];
    command.callbackComplete = ^(id responseObject)
    {
        if (success)
            success(self.launchSession, self.mediaControl);
    };
    command.callbackError = failure;
    [_activeCommands setObject:command forKey:requestId];

    [self sendJSON:message success:nil failure:failure];
}

- (void) playMedia:(NSURL *)mediaURL iconURL:(NSURL *)iconURL title:(NSString *)title description:(NSString *)description mimeType:(NSString *)mimeType shouldLoop:(BOOL)shouldLoop success:(MediaPlayerDisplaySuccessBlock)success failure:(FailureBlock)failure
{
    int requestIdNumber = [self getNextId];
    NSString *requestId = [NSString stringWithFormat:@"req%d", requestIdNumber];

    NSDictionary *message = @{
            @"contentType" : @"connectsdk.mediaCommand",
            @"mediaCommand" : @{
                    @"type" : @"playMedia",
                    @"mediaURL" : ensureString(mediaURL.absoluteString),
                    @"iconURL" : ensureString(iconURL.absoluteString),
                    @"title" : ensureString(title),
                    @"description" : ensureString(description),
                    @"mimeType" : ensureString(mimeType),
                    @"shouldLoop" : @(shouldLoop),
                    @"requestId" : requestId
            }
    };

    ServiceCommand *command = [ServiceCommand commandWithDelegate:nil target:nil payload:nil];
    command.callbackComplete = ^(id responseObject)
    {
        if (success)
            success(self.launchSession, self.mediaControl);
    };
    command.callbackError = failure;
    [_activeCommands setObject:command forKey:requestId];

    [self sendJSON:message success:nil failure:failure];
}

- (void) closeMedia:(LaunchSession *)launchSession success:(SuccessBlock)success failure:(FailureBlock)failure
{
    [self closeWithSuccess:success failure:failure];
}

#pragma mark - Media Control

- (id <MediaControl>) mediaControl
{
    return self;
}

- (CapabilityPriorityLevel) mediaControlPriority
{
    return CapabilityPriorityLevelHigh;
}

- (void)seek:(NSTimeInterval)position success:(SuccessBlock)success failure:(FailureBlock)failure
{
    int requestIdNumber = [self getNextId];
    NSString *requestId = [NSString stringWithFormat:@"req%d", requestIdNumber];

    NSDictionary *message = @{
            @"contentType" : @"connectsdk.mediaCommand",
            @"mediaCommand" : @{
                    @"type" : @"seek",
                    @"position" : @(position),
                    @"requestId" : requestId
            }
    };

    ServiceCommand *command = [ServiceCommand commandWithDelegate:nil target:nil payload:nil];
    command.callbackComplete = success;
    command.callbackError = failure;
    [_activeCommands setObject:command forKey:requestId];

    [self sendJSON:message success:nil failure:failure];
}

- (void)getPositionWithSuccess:(MediaPositionSuccessBlock)success failure:(FailureBlock)failure
{
    int requestIdNumber = [self getNextId];
    NSString *requestId = [NSString stringWithFormat:@"req%d", requestIdNumber];

    NSDictionary *message = @{
            @"contentType" : @"connectsdk.mediaCommand",
            @"mediaCommand" : @{
                    @"type" : @"getPosition",
                    @"requestId" : requestId
            }
    };

    ServiceCommand *command = [ServiceCommand commandWithDelegate:nil target:nil payload:nil];
    command.callbackComplete = ^(NSDictionary *responseObject)
    {
        NSString *positionString = [responseObject objectForKey:@"position"];
        NSTimeInterval position = 0;

        if (positionString && ![positionString isKindOfClass:[NSNull class]])
            position = [positionString intValue];

        if (success)
            success(position);
    };
    command.callbackError = failure;
    [_activeCommands setObject:command forKey:requestId];

    [self sendJSON:message success:nil failure:failure];
}

- (void)getDurationWithSuccess:(MediaDurationSuccessBlock)success failure:(FailureBlock)failure
{
    int requestIdNumber = [self getNextId];
    NSString *requestId = [NSString stringWithFormat:@"req%d", requestIdNumber];

    NSDictionary *message = @{
            @"contentType" : @"connectsdk.mediaCommand",
            @"mediaCommand" : @{
                    @"type" : @"getDuration",
                    @"requestId" : requestId
            }
    };

    ServiceCommand *command = [ServiceCommand commandWithDelegate:nil target:nil payload:nil];
    command.callbackComplete = ^(id responseObject)
    {
        NSString *durationString = [responseObject objectForKey:@"duration"];
        NSTimeInterval duration = 0;

        if (durationString && ![durationString isKindOfClass:[NSNull class]])
            duration = [durationString intValue];

        if (success)
            success(duration);
    };
    command.callbackError = failure;
    [_activeCommands setObject:command forKey:requestId];

    [self sendJSON:message success:nil failure:failure];
}

- (void)getPlayStateWithSuccess:(MediaPlayStateSuccessBlock)success failure:(FailureBlock)failure
{
    int requestIdNumber = [self getNextId];
    NSString *requestId = [NSString stringWithFormat:@"req%d", requestIdNumber];

    NSDictionary *message = @{
            @"contentType" : @"connectsdk.mediaCommand",
            @"mediaCommand" : @{
                    @"type" : @"getPlayState",
                    @"requestId" : requestId
            }
    };

    ServiceCommand *command = [ServiceCommand commandWithDelegate:nil target:nil payload:nil];
    command.callbackComplete = ^(NSDictionary *responseObject)
    {
        NSString *playStateString = [responseObject objectForKey:@"playState"];
        MediaControlPlayState playState = [self parsePlayState:playStateString];

        if (success)
            success(playState);
    };
    command.callbackError = failure;
    [_activeCommands setObject:command forKey:requestId];

    [self sendJSON:message success:nil failure:failure];
}

- (ServiceSubscription *)subscribePlayStateWithSuccess:(MediaPlayStateSuccessBlock)success failure:(FailureBlock)failure
{
    if (!_playStateSubscription)
        _playStateSubscription = [ServiceSubscription subscriptionWithDelegate:nil target:nil payload:nil callId:-1];

    if (!_connected)
        [self connectWithSuccess:nil             failure:failure];

    if (![_playStateSubscription.successCalls containsObject:success])
        [_playStateSubscription addSuccess:success];

    if (![_playStateSubscription.failureCalls containsObject:failure])
        [_playStateSubscription addFailure:failure];

    return _playStateSubscription;
}

@end
