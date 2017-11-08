//
//  YLT_RecordHelper.m
//  ShuaLian
//
//  Created by Done.L on 2017/8/15.
//  Copyright © 2017年 YLT. All rights reserved.
//

#import "YLT_RecordHelper.h"

#import <AVFoundation/AVFoundation.h>

@implementation YLT_RecordHelper

/**
 **	@description    获取录音文件名(以当前时间戳格式生成的字符串)
 **	@returns        录音文件名
 */
+ (NSString *)YLT_RecordSavedPath {
    NSDateFormatter *dateFormatter = [[NSDateFormatter  alloc] init];
    [dateFormatter setDateFormat:@"YYYYMMdd HHmmssSSS"];
    return [dateFormatter stringFromDate:[NSDate date]];
}

/**
 ** @description    录音文件是否存在
 **	@param          录音文件路径
 **	@returns        结果
 */
+ (BOOL)YLT_FileExistsAtPath:(NSString *)path {
    return [[NSFileManager defaultManager] fileExistsAtPath:path];
}

/**
 ** @description    创建文件
 **	@param          录音文件路径
 **	@returns        结果
 */
+ (BOOL)YLT_CreateFileAtPath:(NSString *)path {
    return [[NSFileManager defaultManager] createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:nil];
}

/**
 ** @description    删除文件
 **	@param          录音文件路径
 **	@returns        结果
 */
+ (BOOL)YLT_DeleteFileAtPath:(NSString *)path {
    return [[NSFileManager defaultManager] removeItemAtPath:path error:nil];
}

/**
 ** @description    录音参数设置字典
 **	@returns        设置参数
 */
+ (NSDictionary *)YLT_GetRecordSettings {
    //录音设置
    NSMutableDictionary *recordSettingDictionary = [[NSMutableDictionary alloc] init];
    //设置录音格式  AVFormatIDKey==kAudioFormatLinearPCM
    [recordSettingDictionary setValue:[NSNumber numberWithInt:kAudioFormatLinearPCM] forKey:AVFormatIDKey];
    //设置录音采样率(Hz) 如：AVSampleRateKey==8000/44100/96000（影响音频的质量）
    [recordSettingDictionary setValue:[NSNumber numberWithFloat:11025.f] forKey:AVSampleRateKey];
    //录音通道数  1 或 2
    [recordSettingDictionary setValue:[NSNumber numberWithInt:2] forKey:AVNumberOfChannelsKey];
    //线性采样位数  8、16、24、32
    [recordSettingDictionary setValue:[NSNumber numberWithInt:16] forKey:AVLinearPCMBitDepthKey];
    //录音的质量
    [recordSettingDictionary setValue:[NSNumber numberWithInt:AVAudioQualityMin] forKey:AVEncoderAudioQualityKey];
    [recordSettingDictionary setValue:[NSNumber numberWithBool:NO] forKey:AVLinearPCMIsFloatKey];
    
    return recordSettingDictionary;
}

+ (NSString *)YLT_TmpCafLocalPath {
    NSString *tmpCafLocalPath = [NSTemporaryDirectory() stringByAppendingPathComponent:@"tmp.caf"];
    return tmpCafLocalPath;
}

+ (NSString *)YLT_TmpMp3LocalPath {
    NSString *tmpMp3LocalPath = [NSTemporaryDirectory() stringByAppendingPathComponent:@"mp3.caf"];
    return tmpMp3LocalPath;
}

@end
