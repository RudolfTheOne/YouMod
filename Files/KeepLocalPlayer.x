#import <AVFoundation/AVFoundation.h>
#import <AVKit/AVKit.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <YouTubeHeader/MLAVPlayer.h>
#import <YouTubeHeader/YTPlayerStatus.h>
#import <YouTubeHeader/MDXSessionManager.h>

static BOOL YMReturnNO(id self, SEL _cmd) {
    return NO;
}

static void YMHookBoolGetter(SEL sel) {
    int count = objc_getClassList(NULL, 0);
    if (count <= 0)
        return;
    Class *classes = (Class *)malloc(sizeof(Class) * (unsigned)count);
    count = objc_getClassList(classes, count);
    for (int i = 0; i < count; i++) {
        Class cls = classes[i];
        if (!cls)
            continue;
        @try {
            unsigned int mcount = 0;
            Method *methods = class_copyMethodList(cls, &mcount);
            for (unsigned int j = 0; j < mcount; j++) {
                if (method_getNumberOfArguments(methods[j]) != 2)
                    continue;
                if (!sel_isEqual(method_getName(methods[j]), sel))
                    continue;
                char *type = method_copyReturnType(methods[j]);
                BOOL isBool = (type && type[0] == 'B');
                if (type)
                    free(type);
                if (isBool)
                    method_setImplementation(methods[j], (IMP)YMReturnNO);
                break;
            }
            if (methods)
                free(methods);
        }
        @catch (NSException *e) {}
    }
    free(classes);
}

%hook AVPlayer
- (void)setAllowsExternalPlayback:(BOOL)allowed {
    %orig(NO);
}
- (BOOL)allowsExternalPlayback {
    return NO;
}
- (BOOL)isExternalPlaybackActive {
    return NO;
}
%end

%hook AVAudioSessionPortDescription
- (NSString *)portType {
    NSString *type = %orig;
    if ([type isEqualToString:AVAudioSessionPortAirPlay])
        return AVAudioSessionPortBuiltInSpeaker;
    return type;
}
%end

%hook UIScreen
- (BOOL)isCaptured {
    return NO;
}
+ (NSArray *)screens {
    return @[[UIScreen mainScreen]];
}
%end

%hook UIApplication
- (void)setIdleTimerDisabled:(BOOL)disabled {
    %orig(YES);
}
%end

%group MDX
%hook MDXAirPlayAndBluetoothManager
- (void)airPlayRouteAvailabilityDidChange:(id)arg {
}
- (BOOL)isConnectedToAirPlay {
    return NO;
}
- (void)setConnectedToAirPlay:(BOOL)connected {
    %orig(NO);
}
- (void)startDiscovery {
}
%end
%end

%group MDXSM
%hook MDXSessionManager
- (BOOL)hasActiveMDXOrAirPlaySession {
    return NO;
}
%end
%end

%group YTStatus
%hook YTPlayerStatus
- (BOOL)externalPlayback {
    return NO;
}
%end
%end

%group MLP
%hook MLAVPlayer
- (BOOL)externalPlaybackActive {
    return NO;
}
%end
%end

%ctor {
    %init;
    if (%c(MDXAirPlayAndBluetoothManager))
        %init(MDX);
    if (%c(MDXSessionManager))
        %init(MDXSM);
    if (%c(YTPlayerStatus))
        %init(YTStatus);
    if (%c(MLAVPlayer))
        %init(MLP);
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        YMHookBoolGetter(@selector(outputRouteUsesAirPlay));
        YMHookBoolGetter(@selector(isAirplayable));
        YMHookBoolGetter(@selector(isExternalPlaybackAllowed));
    });
}
