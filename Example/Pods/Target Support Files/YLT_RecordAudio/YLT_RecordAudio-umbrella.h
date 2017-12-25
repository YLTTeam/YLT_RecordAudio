#ifdef __OBJC__
#import <UIKit/UIKit.h>
#else
#ifndef FOUNDATION_EXPORT
#if defined(__cplusplus)
#define FOUNDATION_EXPORT extern "C"
#else
#define FOUNDATION_EXPORT extern
#endif
#endif
#endif

#import "AudioStreamer.h"
#import "lame.h"
#import "YLT_RecordHelper.h"
#import "YLT_RecordManager.h"
#import "LPRecordProgressHUD.h"

FOUNDATION_EXPORT double YLT_RecordAudioVersionNumber;
FOUNDATION_EXPORT const unsigned char YLT_RecordAudioVersionString[];

