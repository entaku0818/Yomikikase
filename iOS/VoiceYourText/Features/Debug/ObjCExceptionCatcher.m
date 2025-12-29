//
//  ObjCExceptionCatcher.m
//  VoiceYourText
//
//  Created by Claude on 2025/12/29.
//

#import "ObjCExceptionCatcher.h"

@implementation ObjCExceptionCatcher

+ (BOOL)catchExceptionWithBlock:(void(^)(void))tryBlock error:(NSError **)error {
    @try {
        tryBlock();
        return YES;
    }
    @catch (NSException *exception) {
        if (error) {
            *error = [NSError errorWithDomain:@"ObjCExceptionDomain"
                                         code:0
                                     userInfo:@{
                NSLocalizedDescriptionKey: exception.reason ?: @"Unknown exception",
                @"ExceptionName": exception.name ?: @"Unknown",
                @"ExceptionReason": exception.reason ?: @"Unknown",
                @"ExceptionUserInfo": exception.userInfo ?: @{}
            }];
        }
        return NO;
    }
}

@end
