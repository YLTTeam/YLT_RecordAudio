//
//  YLT_RecordHelper.h
//  ShuaLian
//
//  Created by Done.L on 2017/8/15.
//  Copyright © 2017年 YLT. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface YLT_RecordHelper : NSObject

/**
 **	@description    获取录音文件名(以当前时间戳格式生成的字符串)
 **	@returns        录音文件名
 */
+ (NSString *)YLT_RecordSavedPath;

/**
 ** @description    录音文件是否存在
 **	@returns        结果
 */
+ (BOOL)YLT_FileExistsAtPath:(NSString *)path;

/**
 ** @description    创建文件
 **	@returns        结果
 */
+ (BOOL)YLT_CreateFileAtPath:(NSString *)path;

/**
 ** @description    删除文件
 **	@returns        结果
 */
+ (BOOL)YLT_DeleteFileAtPath:(NSString *)path;

/**
 ** @description    录音tmpCaf文件路径
 */
+ (NSString *)YLT_TmpCafLocalPath;

/**
 ** @description    录音tmpMp3文件路径
 */
+ (NSString *)YLT_TmpMp3LocalPath;

/**
 ** @description    录音参数设置字典
 **	@returns        设置参数
 */
+ (NSDictionary *)YLT_GetRecordSettings;

@end
