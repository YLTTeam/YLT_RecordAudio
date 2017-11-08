//
//  YLT_RecordProgressHUD.m
//  ShuaLian
//
//  Created by Done.L on 2017/8/15.
//  Copyright © 2017年 YLT. All rights reserved.
//

#import "YLT_RecordProgressHUD.h"

#define YLT_RecordImage(name) [UIImage imageNamed:name inBundle:[NSBundle bundleWithURL:[[NSBundle bundleForClass:[self class]] URLForResource:@"YLT_RecordAudio" withExtension:@"bundle"]] compatibleWithTraitCollection:nil]

static YLT_RecordStatus kRecordStatus;
static NSInteger kRemainTime;

@interface YLT_RecordProgressHUD ()

@property (nonatomic, strong) UIWindow *overlayWindow;

@property (nonatomic, strong) UILabel *message;

@property (nonatomic, strong) UIImageView *micPhoneVolume;

@end

@implementation YLT_RecordProgressHUD

+ (YLT_RecordProgressHUD *)sharedView {
    static dispatch_once_t once;
    static YLT_RecordProgressHUD *sharedView;
    dispatch_once(&once, ^ {
        sharedView = [[YLT_RecordProgressHUD alloc] initWithFrame:CGRectMake(([UIScreen mainScreen].bounds.size.width - 145) / 2, ([UIScreen mainScreen].bounds.size.height - 145) / 2, 145, 145)];
        sharedView.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.5];
        sharedView.layer.cornerRadius = 5.f;
        sharedView.layer.masksToBounds = YES;
    });
    return sharedView;
}

+ (void)YLT_Show {
    [[YLT_RecordProgressHUD sharedView] YLT_Show];
}

+ (void)YLT_RecordStatus:(YLT_RecordStatus)status {
    kRecordStatus = status;
    NSString *title = @"取消";
    NSString *imgName;
    switch (status) {
        case YLT_RecordStatusRecording:
            imgName = @"voice_record_0";
            if (kRemainTime > 0) {
                title = [NSString stringWithFormat:@"还可以说%ld秒", kRemainTime];
            } else {
                title = @"手指上滑，取消发送";
            }
            break;
            
        case YLT_RecordStatusLooseToCancel:
            imgName = @"voice_record_cancel";
            title = @"松开手指取消发送";
            break;
            
        case YLT_RecordStatusTooShort:
            title = @"说话时间太短";
            imgName = @"voice_record_tooshort";
            break;
            
        case YLT_RecordStatusSuccess:
            title = @"完成";
            break;
            
        case YLT_RecordStatusCancel:
            break;
            
        default:
            break;
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        if (imgName) {
            [YLT_RecordProgressHUD sharedView].micPhoneVolume.image = YLT_RecordImage(imgName);
        }
        
        [YLT_RecordProgressHUD sharedView].message.text = title;
        if (status & (YLT_RecordStatusCancel | YLT_RecordStatusTooShort | YLT_RecordStatusSuccess)) {
            [[YLT_RecordProgressHUD sharedView] dismiss:title];
        }
    });
}

+ (void)YLT_RemainTime:(NSInteger)time {
    kRemainTime = MAX(MIN(time, 11), -1);
    if (kRecordStatus == YLT_RecordStatusRecording) {
        [YLT_RecordProgressHUD sharedView].message.text = [NSString stringWithFormat:@"还可以说%ld秒", kRemainTime];
    }
}

+ (void)YLT_RecordVolumeChangeLevel:(NSInteger)level {
    if (kRecordStatus == YLT_RecordStatusRecording) {
        UIImageView *micPhoneImageView = [YLT_RecordProgressHUD sharedView].micPhoneVolume;
        NSString *imgName = [NSString stringWithFormat:@"voice_record_%ld", level];
        micPhoneImageView.image = YLT_RecordImage(imgName);
    }
}

- (void)YLT_Show {
    dispatch_async(dispatch_get_main_queue(), ^{
        [YLT_RecordProgressHUD sharedView].hidden = NO;
        kRecordStatus = YLT_RecordStatusRecording;
        
        if (!self.superview) {
            [self.overlayWindow addSubview:self];
        }
        
        [self addSubview:self.micPhoneVolume];
        [self addSubview:self.message];
        
        [UIView animateWithDuration:0.5f
                              delay:0
                            options:UIViewAnimationOptionAllowUserInteraction | UIViewAnimationCurveEaseOut | UIViewAnimationOptionBeginFromCurrentState
                         animations:^{
                             self.alpha = 1;
                         }
                         completion:nil];
        
        [self setNeedsDisplay];
    });
}

- (void)dismiss:(NSString *)title {
    dispatch_async(dispatch_get_main_queue(), ^{
        kRemainTime = -1;
        CGFloat timeLonger = 0;
        if ([title isEqualToString:@"说话时间太短"]) {
            timeLonger = 0.6;
        }
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(timeLonger * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [_micPhoneVolume removeFromSuperview];
            _micPhoneVolume = nil;
            
            [_message removeFromSuperview];
            _message = nil;
            
            NSMutableArray *windows = [[NSMutableArray alloc] initWithArray:[UIApplication sharedApplication].windows];
            [windows removeObject:_overlayWindow];
            _overlayWindow = nil;
            
            [YLT_RecordProgressHUD sharedView].hidden = YES;
            
            [[NSNotificationCenter defaultCenter] postNotificationName:YLTChatUUVoiceHUDBtnEnableNotification object:nil];
            
            [windows enumerateObjectsWithOptions:NSEnumerationReverse usingBlock:^(UIWindow *window, NSUInteger idx, BOOL *stop) {
                if([window isKindOfClass:[UIWindow class]] && window.windowLevel == UIWindowLevelNormal) {
                    [window makeKeyWindow];
                    *stop = YES;
                }
            }];
        });
    });
}

- (UIImageView *)micPhoneVolume {
    if (!_micPhoneVolume) {
        _micPhoneVolume = [[UIImageView alloc] initWithFrame:CGRectMake((self.bounds.size.width - 36)/2, (self.bounds.size.height - 60 - 16 - 20) / 2, 36, 60)];
        _micPhoneVolume.contentMode = UIViewContentModeScaleAspectFit;
        _micPhoneVolume.image = YLT_RecordImage(@"voice_record_0");
    }
    return _micPhoneVolume;
}

- (UILabel *)message {
    if (!_message) {
        _message = [[UILabel alloc]initWithFrame:CGRectMake(0, _micPhoneVolume.frame.origin.y+_micPhoneVolume.frame.size.height + 16, self.bounds.size.width, 20)];
        self.message.text = @"手向上滑，取消发送";
        self.message.textAlignment = NSTextAlignmentCenter;
        self.message.font = [UIFont boldSystemFontOfSize:13.f];
        self.message.textColor = [UIColor whiteColor];
    }
    return _message;
}

- (UIWindow *)overlayWindow {
    if(!_overlayWindow) {
        _overlayWindow = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
        _overlayWindow.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        _overlayWindow.userInteractionEnabled = YES;
        [_overlayWindow makeKeyAndVisible];
    }
    return _overlayWindow;
}

@end
