//
//  FTRLogger.h
//  ForterSDK
//
//  Created by Or Polaczek on 03/07/2016.
//  Copyright © 2016 Forter. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <FTRCommon/FTRLoggerConstants.h>

@interface FTRLogger : NSObject

/* Manually creating logLevel getter and setter.
 Class properties are too new to use
 //@property (nonatomic, class) int logLevel;
 */

typedef void (^ErrorBlock)(NSString *);

#pragma mark - Log level settings
+ (void)setLogLevel:(int)logLevel;
+ (void)setDevLogsEnabled:(BOOL)enabled;
+ (void)setGlobalErrorHandler: (ErrorBlock) handler;
+ (int)logLevel;

#pragma mark - Logging methods
+ (void)error:(NSString *)log;
+ (void)error:(NSString *)log sendErrorEvent:(BOOL)shouldSendError;
+ (void)warning:(NSString *)log;
+ (void)debug:(NSString *)log;
+ (void)info:(NSString *)log;
+ (void)verbose:(NSString *)log;
+ (void)dev:(NSString *)log;

@end

/* FTRLogger_h */
