//
//  YLT_RecordProgressHUD.h
//  ShuaLian
//
//  Created by Done.L on 2017/8/15.
//  Copyright © 2017年 YLT. All rights reserved.
//

#import <UIKit/UIKit.h>

#define YLTChatUUVoiceHUDBtnEnableNotification @"YLTChatUUVoiceHUDBtnEnableNotification"

typedef NS_ENUM(NSUInteger, YLT_RecordStatus) {
    YLT_RecordStatusTooShort = 1<<1,          // 时间太短了
    YLT_RecordStatusRecording = 1<<2,         // 正在录音
    YLT_RecordStatusLooseToCancel = 1<<3,     // 松开手指取消
    YLT_RecordStatusSuccess = 1<<4,           // 录制完成
    YLT_RecordStatusCancel = 1<<5             // 取消录制
};

@interface YLT_RecordProgressHUD : UIView

/**
 显示状态视图
 */
+ (void)YLT_Show;

/**
 设置录音状态
 
 @param status 录音状态
 */
+ (void)YLT_RecordStatus:(YLT_RecordStatus)status;

/**
 设置语音剩余时间
 
 @param time 时间最大10秒
 */
+ (void)YLT_RemainTime:(NSInteger)time;

/**
 设置音量大小
 
 @param level 音量等级从小到大，范围[0~7]
 */
+ (void)YLT_RecordVolumeChangeLevel:(NSInteger)level;

@end
