//
//  YLT_RecordManager.m
//  ShuaLian
//
//  Created by Done.L on 2017/8/15.
//  Copyright © 2017年 YLT. All rights reserved.
//

#import "YLT_RecordManager.h"

#ifdef DEBUG
#   define DDLog(fmt, ...) NSLog((@"%s [Line %d] " fmt), __PRETTY_FUNCTION__, __LINE__, ##__VA_ARGS__);
#else
#   define DDLog(...)
#endif

#import "lame.h"
#import <AVFoundation/AVFoundation.h>

#import "YLT_RecordHelper.h"
#import "AudioStreamer.h"

static NSInteger kRecordDuration = 0;

@interface YLT_RecordManager () <AVAudioRecorderDelegate, AVAudioPlayerDelegate>

// 录音器
@property (nonatomic, strong) AVAudioRecorder *recorder;

// 播放器
@property (nonatomic, strong) AVAudioPlayer *player;

// 流媒体播放器
@property (nonatomic, strong) AudioStreamer *streamer;

// 录音计时器
@property (nonatomic, strong) NSTimer *recordTimer;

// 音量检测
@property (nonatomic, strong) NSTimer *meterTimer;

// 远程音频进度检测
@property (nonatomic, strong) NSTimer *remoteProgressUpdateTimer;

// 本地播放完成回调
@property (nonatomic, copy) void(^isPlayFinishBlock)(BOOL);

@end

@implementation YLT_RecordManager

+ (instancetype)manager {
    static YLT_RecordManager *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] init];
    });
    
    return sharedInstance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        // 输出设备变更的通知
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(YLT_OutputDeviceChanged:) name:AVAudioSessionRouteChangeNotification object:[AVAudioSession sharedInstance]];
    }
    return self;
}

- (BOOL)isPlaying {
    return _player ? _player.isPlaying : NO;
}

#pragma mark - 停止语音服务

- (void)YLT_StopAudioService {
    [[YLT_RecordManager manager] YLT_CancelRecord];
    [[YLT_RecordManager manager] YLT_CancelPlayRecord];
    [YLT_RecordManager manager].delegate = nil;
    [[YLT_RecordManager manager] YLT_CancelPlayRemoteAudio];
}

#pragma mark - 录音

/**
 * 获取录音权限
 */
- (void)YLT_FetchMicroPhoneRight:(void(^)(BOOL haveRecordRight))completion {
    AVAuthorizationStatus status = [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeAudio];
    BOOL haveRecordRight = NO;
    switch (status) {
        case AVAuthorizationStatusNotDetermined: {
            if([[AVAudioSession sharedInstance] respondsToSelector:@selector(requestRecordPermission:)]) {
                [[AVAudioSession sharedInstance] requestRecordPermission:^(BOOL granted) {}];
            }
        }
            break;
            
        case AVAuthorizationStatusRestricted:
        case AVAuthorizationStatusDenied: {
            [[[UIAlertView alloc] initWithTitle:@"无法录音" message:@"是否允许访问麦克风" delegate:nil cancelButtonTitle:@"我知道了" otherButtonTitles:nil] show];
        }
            break;
            
        case AVAuthorizationStatusAuthorized: {
            NSError *error = nil;
            [[AVAudioSession sharedInstance] setCategory: AVAudioSessionCategoryPlayAndRecord error:&error];
            [[AVAudioSession sharedInstance] setActive:YES error:&error];
            
            haveRecordRight = YES;
        }
            break;
            
        default:
            break;
    }
    
    completion(haveRecordRight);
}

/**
 * 开始录音
 */
- (void)YLT_StartRecord {
#if TARGET_IPHONE_SIMULATOR
    DDLog(@"开始录音！！！");
    
    // 初始化录音器
    [self initAudioRecorder];
    
    [_recorder record];
#else
    [self YLT_FetchMicroPhoneRight:^(BOOL haveRecordRight) {
        if (haveRecordRight) {
            DDLog(@"开始录音！！！");
            
            // 初始化录音器
            [self initAudioRecorder];
            
            [_recorder record];
        } else {
            DDLog(@"没有录音权限！！！");
        }
    }];
#endif
}

/**
 * 完成录音（包括录音时长不够的情况）
 */
- (void)YLT_CompleteRecord {
    double duration = 0;
    duration = (double)_recorder.currentTime;
    
    if (duration > 1.f) {
        // 转换录音格式
        [self YLT_Record_PCMtoMP3];
    } else {
        // 提示
        if ([_delegate respondsToSelector:@selector(YLT_RecordFail)]) {
            [_delegate YLT_RecordFail];
        }
    }
    
    [self YLT_CancelRecord];
}

/**
 * 取消录音
 */
- (void)YLT_CancelRecord {
    [_recorder deleteRecording];
    [self YLT_DestroyAudioRecorder];
}

// 销毁录音器
- (void)YLT_DestroyAudioRecorder {
    if (_recorder) {
        if ([_recorder isRecording]) {
            [_recorder stop];
        }
        _recorder = nil;
        
        // 销毁定时器
        [_recordTimer invalidate];
        _recordTimer = nil;
        
        [_meterTimer invalidate];
        _meterTimer = nil;
        
        // 重置录音计数
        kRecordDuration = 0;
        
        [[AVAudioSession sharedInstance] setActive:NO withOptions:AVAudioSessionSetActiveOptionNotifyOthersOnDeactivation error:nil];
    }
}

// 初始化录音器
- (BOOL)initAudioRecorder {
    // 如果有播放器，先停止播放器
    [self YLT_DestroyAudioPlayer];
    
    // 销毁可能存在的录音器
    [self YLT_DestroyAudioRecorder];
    
    NSError *recorderSetupError = nil;
    
    // 录音本地缓存地址
    NSURL *tmpUrl = [NSURL fileURLWithPath:[YLT_RecordHelper YLT_TmpCafLocalPath]];
    
    // 配置录音参数
    NSDictionary *settings = [YLT_RecordHelper YLT_GetRecordSettings];
    
    _recorder = [[AVAudioRecorder alloc] initWithURL:tmpUrl settings:settings error:&recorderSetupError];
    _recorder.meteringEnabled = YES;
    _recorder.delegate = self;
    
    // 录音计时器
    _recordTimer = [NSTimer scheduledTimerWithTimeInterval:1.f target:self selector:@selector(YLT_RecordTimerAction) userInfo:nil repeats:YES];
    
    // 音量检测
    _meterTimer = [NSTimer scheduledTimerWithTimeInterval:0.01f target:self selector:@selector(YLT_VolumeDetectorAction) userInfo:nil repeats:YES];
    
    if (recorderSetupError) {
        DDLog(@"recorderSetupError = %@", recorderSetupError);
    }
    
    // 录音器是否能准备录音
    return _recorder && [_recorder prepareToRecord];
}

// 录音器计时
- (void)YLT_RecordTimerAction {
    kRecordDuration ++;
    
    if (kRecordDuration >= 60) {
        // 完成录音
        [self YLT_CompleteRecord];
    } else if (kRecordDuration >= 50) {
        // 提示剩余录音时长
        if ([_delegate respondsToSelector:@selector(YLT_RecordTimeRemain:)]) {
            [_delegate YLT_RecordTimeRemain:60 - kRecordDuration];
        }
    }
}

// 环境音量检测
- (void)YLT_VolumeDetectorAction {
    if ([_recorder isRecording]) {
        [_recorder updateMeters];
        
        float lowPassResults;
        float minDecibels = -80.f;
        float decibels = [_recorder averagePowerForChannel:0];
        
        if (decibels < minDecibels) {
            lowPassResults = 0.0f;
        } else if (decibels >= 0.0f) {
            lowPassResults = 1.0f;
        } else {
            float root = 2.0f;
            float minAmp  = powf(10.0f, 0.05f * minDecibels);
            float inverseAmpRange = 1.0f / (1.0f - minAmp);
            float amp = powf(10.0f, 0.05f * decibels);
            float adjAmp = (amp - minAmp) * inverseAmpRange;
            
            lowPassResults = powf(adjAmp, 1.0f / root);
        }
        DDLog(@"%f",lowPassResults);
        
        NSInteger level = 0;
        if (lowPassResults <= 0.1) {
            level = 0;
        } else if (0.1 < lowPassResults <= 0.27) {
            level = 1;
        } else if (0.27 < lowPassResults <= 0.34) {
            level = 2;
        } else if (0.34 < lowPassResults <= 0.48) {
            level = 3;
        } else if (0.48 < lowPassResults <= 0.55) {
            level = 4;
        } else if (0.55 < lowPassResults <= 0.66) {
            level = 5;
        } else if (0.66 < lowPassResults <= 0.75) {
            level = 6;
        } else {
            level = 7;
        }
        
        if ([_delegate respondsToSelector:@selector(YLT_RecordVolumeChanged:)]) {
            [_delegate YLT_RecordVolumeChanged:level];
        }
    }
}

- (void)YLT_Record_PCMtoMP3 {
    NSString *cafPath = [YLT_RecordHelper YLT_TmpCafLocalPath];
    NSString *mp3Path = [YLT_RecordHelper YLT_TmpMp3LocalPath];
    
    // 删除旧的mp3缓存
    [YLT_RecordHelper YLT_DeleteFileAtPath:mp3Path];
    
    DDLog(@"MP3转换开始!!!");
    
    @try {
        unsigned long read;
        unsigned long write;
        
        FILE *pcm = fopen([cafPath cStringUsingEncoding:1], "rb");  // source 被转换的音频文件位置
        fseek(pcm, 4 * 1024, SEEK_CUR);                             // 跳过文件头
        FILE *mp3 = fopen([mp3Path cStringUsingEncoding:1], "wb");  // output 输出生成的mp3文件位置
        
        const int PCM_SIZE = 8192; // 8M
        const int MP3_SIZE = 8192; // 8M
        short int pcm_buffer[PCM_SIZE * 2];
        unsigned char mp3_buffer[MP3_SIZE];
        
        lame_t lame = lame_init();
        lame_set_in_samplerate(lame, 11025.0);
        lame_set_VBR(lame, vbr_default);
        lame_init_params(lame);
        
        do {
            read = fread(pcm_buffer, 2 * sizeof(short int), PCM_SIZE, pcm);
            if (read == 0)
                write = lame_encode_flush(lame, mp3_buffer, MP3_SIZE);
            else
                write = lame_encode_buffer_interleaved(lame, pcm_buffer, (int)read, mp3_buffer, MP3_SIZE);
            
            fwrite(mp3_buffer, write, 1, mp3);
            
        } while (read != 0);
        
        lame_close(lame);
        fclose(mp3);
        fclose(pcm);
    }
    
    @catch (NSException *exception) {
        DDLog(@"%@",[exception description]);
    }
    
    // 删除caf缓存
    [YLT_RecordHelper YLT_DeleteFileAtPath:cafPath];
    
    DDLog(@"MP3转换结束!!!");
    
    if (_delegate && [_delegate respondsToSelector:@selector(YLT_RecordCompleteWithData:recordDuration:)]) {
        NSData *recordData = [NSData dataWithContentsOfFile:mp3Path];
        [_delegate YLT_RecordCompleteWithData:recordData recordDuration:kRecordDuration];
    }
}

#pragma mark - 本地录音播放

/**
 * 播放录音（从本地路径播放）
 */
- (void)YLT_StartPlayRecordWithPath:(NSString *)recordPath completion:(void (^)(BOOL))completion {
    if (!recordPath) {
        return;
    }
    
    NSData *data = [NSData dataWithContentsOfFile:recordPath options:NSDataReadingMappedIfSafe error:nil];
    
    [self YLT_StartPlayRecordWithData:data completion:completion];
}

/**
 * 播放录音（从data播放）
 */
- (void)YLT_StartPlayRecordWithData:(NSData *)data completion:(void(^)(BOOL isFinish))completion {
    // 初始化播放器
    [self initAudioPlayer:data];
    
    _isPlayFinishBlock = completion;
    
    BOOL canPlay = [_player play];
    
    // 处理不能成功播放的情况
    if (!canPlay) {
        [self performSelector:@selector(YLT_StopPlayingUnusefulRecord) withObject:nil afterDelay:0.6f];
    }
}

- (void)YLT_StopPlayingUnusefulRecord {
    if (_isPlayFinishBlock) {
        _isPlayFinishBlock(YES);
    }
}

/**
 * 停止播放
 */
- (void)YLT_CancelPlayRecord {
    [self YLT_DestroyAudioPlayer];
}

// 销毁播放器
- (void)YLT_DestroyAudioPlayer {
    if (_player) {
        if ([_player isPlaying]) {
            [_player stop];
        }
        
        [self YLT_CloseProximityMonitoringEnabled];
        
        _player = nil;
        
        _isPlayFinishBlock = nil;
        
        [[AVAudioSession sharedInstance] setActive:NO withOptions:AVAudioSessionSetActiveOptionNotifyOthersOnDeactivation error:nil];
        
        // 打开自动锁屏
        [UIApplication sharedApplication].idleTimerDisabled = NO;
    }
}

// 初始化播放器
- (BOOL)initAudioPlayer:(NSData *)data {
    // 如果有录音器，先停止录音器
    [self YLT_DestroyAudioRecorder];
    
    // 销毁可能存在的播放器
    [self YLT_DestroyAudioPlayer];
    
    // 声音播放模式
    if (_recordPlayMode) {
        // 听筒
        [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayAndRecord error:nil];
    } else {
        // 扬声器
        [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback error:nil];
        
        // 扬声器模式下才需要打开光感传感器监听
        [self YLT_OpenProximityMonitoringEnabled];
    }
    
    // 关闭自动锁屏
    [UIApplication sharedApplication].idleTimerDisabled = YES;
    
    NSError *playError = nil;
    
    _player = [[AVAudioPlayer alloc] initWithData:data error:&playError];
    _player.delegate = self;
    
    if (playError) {
        DDLog(@"playError = %@", playError);
    }
    
    // 播放器是否能准备播放
    return _player && [_player prepareToPlay];
}

/**
 * 删除录音
 */
- (void)YLT_DeleteRecordAtPath:(NSString *)path {
    if ([YLT_RecordHelper YLT_FileExistsAtPath:path]) {
        [YLT_RecordHelper YLT_DeleteFileAtPath:path];
    }
}

#pragma mark - Proximity Monitoring Setting

- (void)YLT_OpenProximityMonitoringEnabled {
    [[UIDevice currentDevice] setProximityMonitoringEnabled:YES];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(YLT_SensorStateChanged:) name:UIDeviceProximityStateDidChangeNotification object:nil];
}

- (void)YLT_CloseProximityMonitoringEnabled {
    [[UIDevice currentDevice] setProximityMonitoringEnabled:NO];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIDeviceProximityStateDidChangeNotification object:nil];
}

#pragma mark - Notification

// 光感触发器，调整语音播放方式
- (void)YLT_SensorStateChanged:(NSNotification *)notify {
    if ([[UIDevice currentDevice] proximityState]) {
        [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayAndRecord error:nil];
    } else {
        [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback error:nil];
    }
}

// 输出设备变更通知
- (void)YLT_OutputDeviceChanged:(NSNotification *)notification {
    if (notification && notification.userInfo) {
        NSUInteger routeChangeReason = [[notification.userInfo objectForKey:AVAudioSessionRouteChangeReasonKey] unsignedIntegerValue];
        
        switch (routeChangeReason) {
            case AVAudioSessionRouteChangeReasonNewDeviceAvailable: {
                [[AVAudioSession sharedInstance] overrideOutputAudioPort:AVAudioSessionPortOverrideNone error:nil];
            }
                break;
                
            case AVAudioSessionRouteChangeReasonOldDeviceUnavailable: {
                [[AVAudioSession sharedInstance] overrideOutputAudioPort:AVAudioSessionPortOverrideSpeaker error:nil];
            }
                break;
                
            case AVAudioSessionRouteChangeReasonCategoryChange:
                break;
                
            case AVAudioSessionRouteChangeReasonOverride: {
                if ([self YLT_HasHeadphone]) {
                    [[AVAudioSession sharedInstance] overrideOutputAudioPort:AVAudioSessionPortOverrideNone error:nil];
                } else {
                    if (_recordPlayMode) {
                        [[AVAudioSession sharedInstance] overrideOutputAudioPort:AVAudioSessionPortOverrideNone error:nil];
                    } else {
                        [[AVAudioSession sharedInstance] overrideOutputAudioPort:AVAudioSessionPortOverrideSpeaker error:nil];
                    }
                }
            }
                break;
                
            default:
                break;
        }
    }
}

/**
 * 获取设备状态,是否插入耳机,如果插入耳机,返回YES
 */
- (BOOL)YLT_HasHeadphone {
    NSArray *inputsArys = [[AVAudioSession sharedInstance] availableInputs];
    for (AVAudioSessionPortDescription *portDsecription in inputsArys) {
        if ([portDsecription.portType isEqualToString:@"MicrophoneWired"]) {
            return YES;
        }
    }
    
    return NO;
}

#pragma mark - AVAudioRecorderDelegate and AVAudioPlayerDelegate

- (void)audioRecorderDidFinishRecording:(AVAudioRecorder *)recorder successfully:(BOOL)flag {
    DDLog(@"录音完成！！！");
}

- (void)audioRecorderEncodeErrorDidOccur:(AVAudioRecorder *)recorder error:(NSError *)error {
    DDLog(@"录音错误！！！ = %@", error);
}

- (void)audioPlayerDidFinishPlaying:(AVAudioPlayer *)player successfully:(BOOL)flag {
    if (_isPlayFinishBlock) {
        DDLog(@"播放完成！！！");
        _isPlayFinishBlock(flag);
    }
    
    // 停止播放
    [self YLT_CancelPlayRecord];
}

- (void)audioPlayerDecodeErrorDidOccur:(AVAudioPlayer *)player error:(NSError *)error {
    DDLog(@"播放错误！！！ = %@", error);
}


#pragma mark - 远程流媒体播放

/*
 * 播放录音（从远程URL播放）
 */
- (void)YLT_StartPlayRecordWithRemoteURL:(NSString *)remoteURL {
    // 初始化流媒体播放器
    [self initAudioStreamerPlayerWithRemoteURL:remoteURL];
    
    if (_streamer) {
        [_streamer start];
    }
}

- (void)YLT_ReStartPlayRemoteAudio {
    if (_streamer) {
        [_streamer start];
        
        // 重新开启进度更新计时器
        [_remoteProgressUpdateTimer setFireDate:[NSDate date]];
    }
}

- (void)YLT_PausePlayRemoteAudio {
    if (_streamer) {
        [_streamer pause];
        
        // 停止进度更新计时器
        [_remoteProgressUpdateTimer setFireDate:[NSDate distantFuture]];
    }
}

- (void)YLT_CancelPlayRemoteAudio {
    [self YLT_DestroyStreamer];
}

- (void)YLT_RemoteAudioSeekToTime:(float)time {
    if ([_streamer isPlaying] || [_streamer isPaused]) {
        if (_streamer.duration) {
            [_streamer seekToTime:time];
        }
    }
}

- (void)YLT_DestroyStreamer {
    if (_streamer) {
        [[NSNotificationCenter defaultCenter] removeObserver:self name:ASStatusChangedNotification object:_streamer];
        
        [_remoteProgressUpdateTimer invalidate];
        _remoteProgressUpdateTimer = nil;
        
        [_streamer stop];
        _streamer = nil;
        
        [[AVAudioSession sharedInstance] setActive:NO withOptions:AVAudioSessionSetActiveOptionNotifyOthersOnDeactivation error:nil];
    }
}

- (void)initAudioStreamerPlayerWithRemoteURL:(NSString *)remoteURL {
    // 如果有流媒体播放器，先停止播放器
    [self YLT_DestroyStreamer];
    
    NSString *escapedValue = (NSString *)CFBridgingRelease(CFURLCreateStringByAddingPercentEscapes(nil, (CFStringRef)remoteURL, NULL, NULL, kCFStringEncodingUTF8)) ;
    ;
    
    NSURL *url = [NSURL URLWithString:escapedValue];
    _streamer = [[AudioStreamer alloc] initWithURL:url];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(YLT_AudioStreamerStatusChanged:) name:ASStatusChangedNotification object:nil];
    
    // 进度检测
    _remoteProgressUpdateTimer = [NSTimer scheduledTimerWithTimeInterval:0.1f target:self selector:@selector(YLT_RemoteAudioProgressUpdate) userInfo:nil repeats:YES];
}

/**
 远程音频播放进度检测
 */
- (void)YLT_RemoteAudioProgressUpdate {
    if (_streamer.bitRate != 0.0) {
        double progress = _streamer.progress;
        double duration = _streamer.duration;
        
        if (duration > 0) {
            if (self.delegate && [self.delegate respondsToSelector:@selector(YLT_RemoteAudioProgressChanged:duration:)]) {
                [self.delegate YLT_RemoteAudioProgressChanged:progress duration:duration];
            }
        } else {
            DDLog(@"远程音频总时长为0!");
        }
    } else {
        
    }
}

/**
 远程播放状态变化检测
 
 @param notify 通知
 */
- (void)YLT_AudioStreamerStatusChanged:(NSNotification *)notify {
    if ([_streamer isWaiting]) {
        DDLog(@"音频正在缓冲...");
        if (self.delegate && [self.delegate respondsToSelector:@selector(YLT_RemoteAudioStateChanged:)]) {
            [self.delegate YLT_RemoteAudioStateChanged:REMOTE_AUDIO_STATE_BUFFERING];
        }
    } else if ([_streamer isPlaying]) {
        DDLog(@"音频正在播放...");
        if (self.delegate && [self.delegate respondsToSelector:@selector(YLT_RemoteAudioStateChanged:)]) {
            [self.delegate YLT_RemoteAudioStateChanged:REMOTE_AUDIO_STATE_PLAYING];
        }
    } else if ([_streamer isPaused]) {
        DDLog(@"音频暂停播放...");
        if (self.delegate && [self.delegate respondsToSelector:@selector(YLT_RemoteAudioStateChanged:)]) {
            [self.delegate YLT_RemoteAudioStateChanged:REMOTE_AUDIO_STATE_PAUSE];
        }
    } else if ([_streamer isIdle]) {
        DDLog(@"音频播放完成...");
        if (self.delegate && [self.delegate respondsToSelector:@selector(YLT_RemoteAudioStateChanged:)]) {
            [self.delegate YLT_RemoteAudioStateChanged:REMOTE_AUDIO_STATE_STOP];
        }
    }
}

@end
