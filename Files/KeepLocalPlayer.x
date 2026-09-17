#import <AVFoundation/AVFoundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static BOOL YMReturnNO(id self, SEL _cmd) {
    return NO;
}

static void YMHookBoolGetter(SEL sel) {
    int count = objc_getClassList(NULL, 0);
    Class *classes = (Class *)malloc(sizeof(Class) * (unsigned)count);
    count = objc_getClassList(classes, count);
    for (int i = 0; i < count; i++) {
        Method m = class_getInstanceMethod(classes[i], sel);
        if (!m || method_getNumberOfArguments(m) != 2)
            continue;
        char *type = method_copyReturnType(m);
        if (type && type[0] == 'B')
            method_setImplementation(m, (IMP)YMReturnNO);
        free(type);
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

%ctor {
    %init;
    if (%c(MDXAirPlayAndBluetoothManager))
        %init(MDX);
    YMHookBoolGetter(@selector(outputRouteUsesAirPlay));
    YMHookBoolGetter(@selector(isAirplayable));
    YMHookBoolGetter(@selector(isExternalPlaybackAllowed));
}
