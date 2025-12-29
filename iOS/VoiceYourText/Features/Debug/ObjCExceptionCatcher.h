//
//  ObjCExceptionCatcher.h
//  VoiceYourText
//
//  Created by Claude on 2025/12/29.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface ObjCExceptionCatcher : NSObject

+ (BOOL)catchExceptionWithBlock:(void(^)(void))tryBlock
                          error:(NSError *_Nullable *_Nullable)error;

@end

NS_ASSUME_NONNULL_END
