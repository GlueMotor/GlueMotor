//
//  GlueMotorCore.h
//  GlueMotorCore
//
//  Created by Kazuhisa "Kazu" Terasaki on 5/26/13.
//  Copyright © 2013-2016 Kazuhisa Terasaki All rights reserved.
//  https://github.com/gluemotor
//

#import <Foundation/Foundation.h>

@class GlueMotorCore;

#pragma mark - GlueMotorCoreDelegate

@protocol GlueMotorCoreDelegate <NSObject>

@optional
// called just before the next PWM cycle will be started so set the Pulse Width from this delegate method will minimize the latency
// NOTE: this delegate method will be called in Audio Queue thread, so don't call the UI related API from there.
- (void)glueMotorCoreWillStartPWMCycle:(GlueMotorCore *)glueMotor;

@end

#pragma mark - GlueMotorCore

@interface GlueMotorCore : NSObject

@property (weak, nonatomic) id<GlueMotorCoreDelegate> delegate;
@property (nonatomic) BOOL allowAudioOutputInBackground;

+ (id)sharedInstance;
+ (NSUInteger)supportedServoCount;

// pulseWidth: in seconds (e.g. 0.0015 = 1.5ms = center position), 0.0 = PWM OFF
// servoIndex: 0 (L) or 1 (R)
- (void)setPulseWidth:(NSTimeInterval)pulseWidth forServo:(NSUInteger)servoIndex;

- (NSTimeInterval)pulseWidthForServo:(NSUInteger)servoIndex;

// value: 0.0 ~ 1.0
- (void)setPWMVolume:(float)volume;

@end
