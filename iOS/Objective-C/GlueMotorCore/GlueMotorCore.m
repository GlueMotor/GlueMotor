//
//  GlueMotorCore.m
//  GlueMotorCore
//
//  Created by Kazuhisa "Kazu" Terasaki on 5/26/13.
//  Copyright © 2013-2016 Kazuhisa Terasaki All rights reserved.
//  https://github.com/gluemotor
//

#import "GlueMotorCore.h"
#import <AudioToolbox/AudioToolbox.h>
#import <AVFoundation/AVAudioSession.h>
#import <MediaPlayer/MediaPlayer.h>

#define SUPPORTED_SERVO_COUNT       2
#define AUDIO_SAMPLING_RATE         44100.0
#define AUDIO_BUFFER_COUNT          4
#define AUDIO_BUFFER_LENGTH_IN_SEC  0.005

static NSString *kUserDefaultsOriginalVolumeKey  = @"GlueMotorCore_OriginalVolume";
static NSString *kUserDefaultsGlueMotorVolumeKey = @"GlueMotorCore_GlueMotorVolume";

#pragma mark - GlueMotorCore interface

@interface GlueMotorCore () {
    NSTimeInterval _pulseWidth[SUPPORTED_SERVO_COUNT];
    NSTimeInterval _nextPulseWidth[SUPPORTED_SERVO_COUNT];
    AudioStreamBasicDescription _audioDesc;
    AudioQueueRef _audioQueue;
    NSUInteger _currentAudioBufferIndex;
    NSUInteger _currentServoIndex;
}

@end

#pragma mark - GlueMotorCore implementation

@implementation GlueMotorCore

#pragma mark class methods

+ (GlueMotorCore *)sharedInstance {
    static GlueMotorCore *sSharedInstance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sSharedInstance = [[GlueMotorCore alloc] init];
    });
    return sSharedInstance;
}

+ (NSUInteger)supportedServoCount {
    return SUPPORTED_SERVO_COUNT;
}

#pragma mark - instance methods

- (id)init {
    self = [super init];
    if (self != nil) {
        _currentAudioBufferIndex = 0;
        _currentServoIndex = 0;
        for (NSInteger servoIndex = 0; servoIndex < SUPPORTED_SERVO_COUNT; servoIndex++) {
            _pulseWidth[servoIndex] = 0.0;
            _nextPulseWidth[servoIndex] = 0.0;
        }
        
        // start AudioQueue
        [self initAudioSession];
        if ([self isAudioRouteHeadphones] == YES) {
            [self startAudioQueue];
        }
        
        [self addObservers];
    }
    return self;
}

- (void)dealloc {
    [self removeObservers];
    [self stopAudioQueue];
}

- (void)setPulseWidth:(NSTimeInterval)pulseWidth forServo:(NSUInteger)servoIndex {
    NSAssert(servoIndex < SUPPORTED_SERVO_COUNT, @"only support up to %d servo motors", SUPPORTED_SERVO_COUNT);
    
    _nextPulseWidth[servoIndex] = pulseWidth;
}

- (NSTimeInterval)pulseWidthForServo:(NSUInteger)servoIndex {
    NSAssert(servoIndex < SUPPORTED_SERVO_COUNT, @"only support up to %d servo motors", SUPPORTED_SERVO_COUNT);
    
    return _nextPulseWidth[servoIndex];
}

- (void)setPWMVolume:(float)volume {
    if ([self isAudioQueueRunning] && [self isAudioRouteHeadphones]) {
        if ([self getAudioVolume] != volume) {
            [self setAudioVolume:volume];
        }
    }
    [self saveGlueMotorVolume:volume];
}

#pragma mark - Notification Handler

- (void)addObservers {
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    [nc addObserver:self selector:@selector(applicationDidBecomeActive:) name:UIApplicationDidBecomeActiveNotification object:nil];
    [nc addObserver:self selector:@selector(applicationWillResignActive:) name:UIApplicationWillResignActiveNotification object:nil];
}

- (void)removeObservers {
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    [nc removeObserver:self name:UIApplicationDidBecomeActiveNotification object:nil];
    [nc removeObserver:self name:UIApplicationWillResignActiveNotification object:nil];
}

- (void)applicationDidBecomeActive:(NSNotification *)notification {
    NSLog(@"applicationDidBecomeActive");
    if ([self isAudioRouteHeadphones] == YES) {
        [self stopAudioQueue];
        [self startAudioQueue];
    }
}

- (void)applicationWillResignActive:(NSNotification *)notification {
    NSLog(@"applicationWillResignActive");
    if (self.allowAudioOutputInBackground == NO) {
        [self stopAudioQueue];
    }
}

- (BOOL)isApplicationActive {
    UIApplication *app = [UIApplication sharedApplication];
    return ([app applicationState] == UIApplicationStateActive);
}

#pragma mark - AudioSession

- (void)initAudioSession {
    AVAudioSession *as = [AVAudioSession sharedInstance];
    NSError *err;
    [as setPreferredHardwareSampleRate:AUDIO_SAMPLING_RATE error:&err];
    NSTimeInterval duration = AUDIO_BUFFER_LENGTH_IN_SEC;
    [as setPreferredIOBufferDuration:duration error:&err];
    [as setCategory:AVAudioSessionCategoryPlayback error:&err];
    [as setActive:YES error:&err];
    
    OSStatus status;
    status = AudioSessionAddPropertyListener(kAudioSessionProperty_AudioRouteChange, audioSessionPropertyListenerCallback, (__bridge void*)self);
    status = AudioSessionAddPropertyListener(kAudioSessionProperty_CurrentHardwareOutputVolume, audioSessionPropertyListenerCallback, (__bridge void*)self);
}

- (void)cleanupAudioSession {
    OSStatus status;
    status = AudioSessionRemovePropertyListenerWithUserData(kAudioSessionProperty_AudioRouteChange, audioSessionPropertyListenerCallback, (__bridge void*)self);
    status = AudioSessionRemovePropertyListenerWithUserData(kAudioSessionProperty_CurrentHardwareOutputVolume, audioSessionPropertyListenerCallback, (__bridge void*)self);
    AVAudioSession *as = [AVAudioSession sharedInstance];
    NSError *err;
    [as setActive:NO error:&err];
}

void audioSessionPropertyListenerCallback(void                   *inUserData,
                                          AudioSessionPropertyID inPropertyID,
                                          UInt32                 inPropertyValueSize,
                                          const void             *inPropertyValue)
{
    GlueMotorCore *self = (__bridge GlueMotorCore *)inUserData;
    if (inPropertyID == kAudioSessionProperty_AudioRouteChange) {
        CFDictionaryRef routeChangeDictRef = (CFDictionaryRef)inPropertyValue;
        if (routeChangeDictRef != nil) {
            CFDictionaryRef routeDictRef = CFDictionaryGetValue(routeChangeDictRef, kAudioSession_AudioRouteChangeKey_CurrentRouteDescription);
            if (routeDictRef != nil) {
                BOOL result = [self isAudioRouteHeadphones:routeDictRef];
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (result == YES) {
                        // connected to headset
                        [self startAudioQueue];
                    }
                    else {
                        // disconnected from headset
                        [self stopAudioQueue];
                    }
                });
            }
        }
    }
    else if (inPropertyID == kAudioSessionProperty_CurrentHardwareOutputVolume) {
        Float32 volume = *((Float32 *)inPropertyValue);
        NSLog(@"volume=%f", (float)volume);
        if ([self isAudioQueueRunning] && [self isAudioRouteHeadphones]) {
            [self saveGlueMotorVolume];
        }
    }
}

- (BOOL)isAudioRouteHeadphones {
    BOOL result = NO;
    CFDictionaryRef routeDictRef = nil;
    UInt32 size = sizeof(routeDictRef);
    OSStatus status = AudioSessionGetProperty(kAudioSessionProperty_AudioRouteDescription, &size, &routeDictRef);
    if (status == kAudioSessionNoError && routeDictRef != nil) {
        result = [self isAudioRouteHeadphones:routeDictRef];
    }
    return result;
}

- (BOOL)isAudioRouteHeadphones:(CFDictionaryRef)routeDictRef {
    BOOL result = NO;
    CFArrayRef outputRoutesRef = CFDictionaryGetValue(routeDictRef, kAudioSession_AudioRouteKey_Outputs);
    if (outputRoutesRef != nil && CFArrayGetCount(outputRoutesRef) > 0) {
        CFDictionaryRef outputDictRef = CFArrayGetValueAtIndex(outputRoutesRef, 0);
        if (outputDictRef != nil) {
            CFStringRef routeRef = CFDictionaryGetValue(outputDictRef, kAudioSession_AudioRouteKey_Type);
            if (routeRef != nil && CFStringCompare(routeRef, kAudioSessionOutputRoute_Headphones, 0) == kCFCompareEqualTo) {
                result = YES;
            }
        }
    }
    NSLog(@"Is AudioRoute headphone? %d", result);
    return result;
}

#pragma mark - Volume Control

- (float)getAudioVolume {
    MPMusicPlayerController *mp = [MPMusicPlayerController applicationMusicPlayer];
    return mp.volume;
}

- (void)setAudioVolume:(float)volume {
    MPMusicPlayerController *mp = [MPMusicPlayerController applicationMusicPlayer];
    mp.volume = volume;
}

- (void)saveOriginalVolume {
    float volume = [self getAudioVolume];
    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
    float gmVolume = [ud floatForKey:kUserDefaultsGlueMotorVolumeKey];
    if (volume == gmVolume && volume != 0.0) {
        NSLog(@"volume == GlueMotorVolume, don't save as original volume: %f", (float)volume);
    }
    else {
        NSLog(@"saving original volume: %f", (float)volume);
        [ud setFloat:volume forKey:kUserDefaultsOriginalVolumeKey];
        if (gmVolume == 0.0) {
            // just in case the volume is already 1.0 at initial launch
            NSLog(@"saving GlueMotor volume: %f", (float)volume);
            [ud setFloat:volume forKey:kUserDefaultsGlueMotorVolumeKey];
        }
        [ud synchronize];
    }
}

- (void)restoreOriginalVolume {
    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
    float volume = [ud floatForKey:kUserDefaultsOriginalVolumeKey];
    NSLog(@"restoring original volume: %f", (float)volume);
    [self setAudioVolume:volume];
}

- (void)saveGlueMotorVolume {
    float volume = [self getAudioVolume];
    [self saveGlueMotorVolume:volume];
}

- (void)saveGlueMotorVolume:(float)volume {
    NSLog(@"saving GlueMotor volume: %f", (float)volume);
    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
    [ud setFloat:volume forKey:kUserDefaultsGlueMotorVolumeKey];
    [ud synchronize];
}

- (void)restoreGlueMotorVolume {
    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
    float volume = [ud floatForKey:kUserDefaultsGlueMotorVolumeKey];
    if (volume != 0.0) {
        NSLog(@"restoring GlueMotor volume: %f", (float)volume);
        [self setAudioVolume:volume];
    }
}

#pragma mark - AudioQueue

- (void)startAudioQueue {
    if ([self isApplicationActive] == NO) {
        return;
    }
    
    if (_audioQueue != NULL && [self isAudioQueueRunning] == NO) {
        [self stopAudioQueue];
    }
    
    if (_audioQueue == NULL) {
        if ([self isAudioRouteHeadphones]) {
            [self saveOriginalVolume];
            [self restoreGlueMotorVolume];
        }
        [self initAudioQueue];
    }
}

- (void)stopAudioQueue {
    if (_audioQueue != NULL) {
        if ([self isAudioRouteHeadphones]) {
            [self restoreOriginalVolume];
        }
        [self cleanupAudioQueue];
    }
}

- (BOOL)isAudioQueueRunning {
    BOOL isRunning = NO;
    if (_audioQueue != NULL) {
        UInt32 running = 0;
        UInt32 size = sizeof(UInt32);
        OSStatus status = AudioQueueGetProperty(_audioQueue, kAudioQueueProperty_IsRunning, &running, &size);
        NSLog(@"status=%d", (int)status);
        isRunning = (running != 0);
    }
    return isRunning;
}

- (void)initAudioQueue {
    _audioDesc.mSampleRate = AUDIO_SAMPLING_RATE;
    _audioDesc.mFormatID = kAudioFormatLinearPCM;
    _audioDesc.mFormatFlags = kLinearPCMFormatFlagIsSignedInteger | kLinearPCMFormatFlagIsPacked;
    _audioDesc.mBitsPerChannel = sizeof(SInt16) * 8;
    _audioDesc.mChannelsPerFrame = 2;
    _audioDesc.mBytesPerFrame = (_audioDesc.mBitsPerChannel / 8) * _audioDesc.mChannelsPerFrame;
    _audioDesc.mFramesPerPacket = 1;
    _audioDesc.mBytesPerPacket = _audioDesc.mBytesPerFrame * _audioDesc.mFramesPerPacket;
    _audioDesc.mReserved = 0;
    OSStatus status = AudioQueueNewOutput(&_audioDesc, audioQueueOutputCallback, (__bridge void *)self, CFRunLoopGetCurrent(), kCFRunLoopCommonModes, 0, &_audioQueue);
    NSLog(@"status=%d", (int)status);
    
    UInt32 bufferSize = roundf(AUDIO_BUFFER_LENGTH_IN_SEC * _audioDesc.mSampleRate) * _audioDesc.mBytesPerFrame;
    for (NSInteger i = 0; i < AUDIO_BUFFER_COUNT; i++) {
        AudioQueueBufferRef audioQueueBuffer;
        AudioQueueAllocateBuffer(_audioQueue, bufferSize, &audioQueueBuffer);
        audioQueueOutputCallback((__bridge void *)self, _audioQueue, audioQueueBuffer);
    }
    
    AudioQueueStart(_audioQueue, nil);
    NSLog(@"AudioQueue started");
}

- (void)cleanupAudioQueue {
    AudioQueueStop(_audioQueue, YES);
    AudioQueueDispose(_audioQueue, YES);
    _audioQueue = NULL;
    NSLog(@"AudioQueue stopped");
}

void audioQueueOutputCallback(void *inUserData, AudioQueueRef inAQ, AudioQueueBufferRef inBuffer) {
    return [(__bridge GlueMotorCore *)inUserData audioQueueOutputCallback:inAQ audioQueueBuffer:inBuffer];
}

- (void)audioQueueOutputCallback:(AudioQueueRef)inAQ audioQueueBuffer:(AudioQueueBufferRef)inBuffer {
    UInt32 numFrames = inBuffer->mAudioDataBytesCapacity / _audioDesc.mBytesPerPacket;
    SInt16 *p = (SInt16 *)inBuffer->mAudioData;
    
    if (_currentAudioBufferIndex == 0) {
        if (self.delegate != nil && [self.delegate respondsToSelector:@selector(glueMotorCoreWillStartPWMCycle:)]) {
            [self.delegate glueMotorCoreWillStartPWMCycle:self];
        }
        for (NSUInteger servoIndex = 0; servoIndex < SUPPORTED_SERVO_COUNT; servoIndex++) {
            _pulseWidth[servoIndex] = _nextPulseWidth[servoIndex];
        }
    }
    
    //
    // Thank you for reading my dirty source code. You are now reaching the GlueMotor's core part. 
    // Rest of the code are pretty obvious, but the next block is only the part that may be considered as "invention",
    // that I have came up with when I was thinking about how to improve the PWM resolution, and here is how I have solved!
    // Just in case if you feel something from this idea and want to poke me: email:support@gluemotor.com, twitter:@gluemotor
    //
    double pulseWidthSamplesDouble = _pulseWidth[_currentServoIndex] * _audioDesc.mSampleRate;    // e.g. 0.00145 sec. * 44100.0 samples/sec. = 63.945 samples
    NSInteger pulseWidthSamples = floor(pulseWidthSamplesDouble);
    SInt16 fallEdge = -32768.0 + 65535.0 * (pulseWidthSamplesDouble - (double)pulseWidthSamples); // e.g. -32768.0 + 65535.0 * (63.945 - 63) = 29162.575
    if (pulseWidthSamples >= numFrames) {
        pulseWidthSamples = numFrames - 1;
    }
    //NSLog(@"%d: %.3f %d %d", sCurrentServoIndex, _pulseWidth[sCurrentServoIndex] * 1000.0, pulseWidthSamples, (NSInteger)fallEdge);
    
    
    SInt16 hi = 32767;
    SInt16 lo = -32768;
    
    SInt16 hi0 = lo;
    SInt16 hi1 = lo;
    SInt16 fallEdge0 = lo;
    SInt16 fallEdge1 = lo;
    if (_currentAudioBufferIndex == 0) {
        hi0 = hi;
        fallEdge0 = fallEdge;
        _currentServoIndex++;
    }
    else if (_currentAudioBufferIndex == (NSInteger)(0.010 / AUDIO_BUFFER_LENGTH_IN_SEC)) {
        hi1 = hi;
        fallEdge1 = fallEdge;
        _currentServoIndex++;
    }
    
    if (_currentServoIndex >= SUPPORTED_SERVO_COUNT) {
        _currentServoIndex = 0;
    }
    
    // high pulse
    for (NSInteger cnt = pulseWidthSamples; cnt > 0; cnt--) {
        *p++ = hi0;
        *p++ = hi1;
    }
    
    // falling edge
    *p++ = fallEdge0;
    *p++ = fallEdge1;
    
    // low pulse
    for (NSInteger cnt = (numFrames - pulseWidthSamples - 1); cnt > 0; cnt--) {
        *p++ = lo;
        *p++ = lo;
    }
    
    if (++_currentAudioBufferIndex >= (NSInteger)(0.020 / AUDIO_BUFFER_LENGTH_IN_SEC)) {
        _currentAudioBufferIndex = 0;
    }
    
    inBuffer->mPacketDescriptionCount = numFrames;
    inBuffer->mAudioDataByteSize = numFrames * _audioDesc.mBytesPerFrame;
    AudioQueueEnqueueBuffer(inAQ, inBuffer, 0, NULL);
}

@end
