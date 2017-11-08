//
//  YLTViewController.m
//  YLT_RecordAudio
//
//  Created by xphaijj0305@126.com on 11/08/2017.
//  Copyright (c) 2017 xphaijj0305@126.com. All rights reserved.
//

#import "YLTViewController.h"
#import <AVFoundation/AVFoundation.h>
#import <YLT_RecordAudio/YLT_RecordAudio.h>

@interface YLTViewController ()<YLT_RecordManagerDelegate>

@end

@implementation YLTViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    [self configRecord];
    UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
    [btn setTitle:@"按住录音" forState:UIControlStateNormal];
    btn.frame = CGRectMake(100, 100, 100, 100);
    [btn setTitleColor:[UIColor blueColor] forState:UIControlStateNormal];
    [btn addTarget:self action:@selector(beginRecordVoice:) forControlEvents:UIControlEventTouchDown];
    [btn addTarget:self action:@selector(completeRecordVoice:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:btn];
    
//    UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
//    [btn setTitle:@"播放" forState:UIControlStateNormal];
//    btn.frame = CGRectMake(100, 250, 100, 100);
//    [btn addTarget:self action:@selector(beginRecordVoice:) forControlEvents:UIControlEventTouchDown];
//    [btn addTarget:self action:@selector(completeRecordVoice:) forControlEvents:UIControlEventTouchUpInside];
//    [self.view addSubview:btn];
    
}

- (void)configRecord {
    [YLT_RecordManager manager].delegate = self;
    [YLT_RecordManager manager].recordPlayMode = 0;
}

#pragma mark - 录音按钮事件

// 开始录音
- (void)beginRecordVoice:(UIButton *)button {
    AVAuthorizationStatus authorStatus = [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeAudio];
    if(authorStatus == AVAuthorizationStatusRestricted || authorStatus == AVAuthorizationStatusDenied){
//        UIAlertView *alertView = [[UIAlertView alloc]initWithTitle:@"提示" message:@"请在iPhone的“设置-隐私-麦克风”选项中，允许刷脸访问你的麦克风" delegate:nil cancelButtonTitle:@"确定" otherButtonTitles:nil, nil];
//        [alertView show];
        return;
    }
    
    [[YLT_RecordManager manager] YLT_StartRecord];
    [YLT_RecordProgressHUD YLT_Show];
    
    button.userInteractionEnabled = NO;
}

// 完成录音
- (void)completeRecordVoice:(UIButton *)button {
    [[YLT_RecordManager manager] YLT_CompleteRecord];
}

// 取消录音
- (void)cancelRecordVoice:(UIButton *)button {
    [[YLT_RecordManager manager] YLT_CancelRecord];
    
    [YLT_RecordProgressHUD YLT_RecordStatus:YLT_RecordStatusCancel];
}

// 松手停止录音
- (void)remindDragExit:(UIButton *)button {
    [YLT_RecordProgressHUD YLT_RecordStatus:YLT_RecordStatusLooseToCancel];
}

// 继续录音
- (void)remindDragEnter:(UIButton *)button {
    [YLT_RecordProgressHUD YLT_RecordStatus:YLT_RecordStatusRecording];
}

// 语音按钮状态改变通知
- (void)voiceRecordButtonChanged:(NSNotification *)notification {
//    _btnVoiceRecord.userInteractionEnabled = YES;
}

#pragma mark - YLT_RecordManagerDelegate

// 录音成功
- (void)YLT_RecordCompleteWithData:(NSData *)recordData recordDuration:(NSInteger)recordDuration {
//    if (self.userInteractionEnabled) {
//        [self.delegate LPChatFunctionView:self sendVoice:recordData time:recordDuration];
        [YLT_RecordProgressHUD YLT_RecordStatus:YLT_RecordStatusSuccess];
//    } else {
//        [YLT_RecordProgressHUD setRecordStatus:YLT_RecordStatusCancel];
//    }
    
    //缓冲消失时间 (最好有block回调消失完成)
//    self.btnVoiceRecord.enabled = NO;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
//        self.btnVoiceRecord.enabled = YES;
    });
}

// 录音失败
- (void)YLT_RecordFail {
    [YLT_RecordProgressHUD YLT_RecordStatus:YLT_RecordStatusTooShort];
    
    //缓冲消失时间 (最好有block回调消失完成)
//    self.btnVoiceRecord.enabled = NO;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
//        self.btnVoiceRecord.enabled = YES;
    });
}

// 音量变化
- (void)YLT_RecordVolumeChanged:(NSInteger)volume {
    [YLT_RecordProgressHUD YLT_RecordVolumeChangeLevel:volume];
}

// 剩余时长
- (void)YLT_RecordTimeRemain:(NSInteger)remain {
    [YLT_RecordProgressHUD YLT_RemainTime:remain];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
