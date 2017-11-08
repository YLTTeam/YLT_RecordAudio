//
//  YLT_RecordManager.h
//  ShuaLian
//
//  Created by Done.L on 2017/8/15.
//  Copyright © 2017年 YLT. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef enum : NSUInteger {
    REMOTE_AUDIO_STATE_BUFFERING = 0,   // 正在缓冲
    REMOTE_AUDIO_STATE_PLAYING,         // 正在播放
    REMOTE_AUDIO_STATE_PAUSE,           // 播放暂停
    REMOTE_AUDIO_STATE_STOP             // 播放停止
} REMOTE_AUDIO_STATE;

@protocol YLT_RecordManagerDelegate <NSObject>

@optional

/**
 * 音量变化
 */
- (void)YLT_RecordVolumeChanged:(NSInteger)volume;

/**
 * 录音剩余时长
 */
- (void)YLT_RecordTimeRemain:(NSInteger)remain;

/**
 * 录音完成
 */
- (void)YLT_RecordCompleteWithData:(NSData *)recordData recordDuration:(NSInteger)recordDuration;

/**
 * 录音失败
 */
- (void)YLT_RecordFail;

/**
 * 远程流媒体状态
 */
- (void)YLT_RemoteAudioStateChanged:(REMOTE_AUDIO_STATE)state;

/**
 * 远程流媒体进度检测
 */
- (void)YLT_RemoteAudioProgressChanged:(double)progress duration:(double)duration;

@end

@interface YLT_RecordManager : NSObject

/**
 * 单例
 */
+ (instancetype)manager;

@property (nonatomic, assign) id<YLT_RecordManagerDelegate> delegate;

/**
 * 播放模式 (0 表示扬声器，1 表示听筒)
 */
@property (nonatomic, assign) BOOL recordPlayMode;

/**
 * 是否正在播放录音
 */
@property (nonatomic, assign, readonly) BOOL isPlaying;

#pragma mark - 录音

/**
 * 开始录音
 */
- (void)YLT_StartRecord;

/**
 * 完成录音（包括录音时长不够的情况）
 */
- (void)YLT_CompleteRecord;

/**
 * 取消录音
 */
- (void)YLT_CancelRecord;


#pragma mark - 本地录音播放

/*
 * 播放录音（从本地路径播放）
 */
- (void)YLT_StartPlayRecordWithPath:(NSString *)recordPath completion:(void(^)(BOOL isFinish))completion;

/*
 * 播放录音（从data播放）
 */
- (void)YLT_StartPlayRecordWithData:(NSData *)data completion:(void(^)(BOOL isFinish))completion;

/*
 * 停止播放
 */
- (void)YLT_CancelPlayRecord;

/*
 * 删除录音
 */
- (void)YLT_DeleteRecordAtPath:(NSString *)path;


#pragma mark - 远程流媒体播放

/**
 播放远程音频
 
 @param remoteURL 音频链接
 */
- (void)YLT_StartPlayRecordWithRemoteURL:(NSString *)remoteURL;

/**
 继续播放远程音频
 */
- (void)YLT_ReStartPlayRemoteAudio;

/**
 暂停播放远程音频
 */
- (void)YLT_PausePlayRemoteAudio;

/**
 停止播放远程音频
 */
- (void)YLT_CancelPlayRemoteAudio;

/**
 停止播放远程音频
 */
- (void)YLT_RemoteAudioSeekToTime:(float)time;

#pragma mark - 停止语音服务

- (void)YLT_StopAudioService;

@end
