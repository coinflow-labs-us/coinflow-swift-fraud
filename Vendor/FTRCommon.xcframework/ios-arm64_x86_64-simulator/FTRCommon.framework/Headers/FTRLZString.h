//
//  FTRLZString.h
//  ForterSDK
//
//  Created by Yoav on 24/07/2017.
//  Copyright © 2017 Forter. All rights reserved.
//
#pragma once

#import <Foundation/Foundation.h>

@interface FTRLZString : NSObject
+ (nonnull NSString *) compressLZ:(nonnull NSString *)data bitsPerChar:(int)bitsPerChar withWrapper:(nonnull NSString *_Nonnull (^)(int))wrapper;
- (nullable NSString *) decompressLZ:(NSInteger)length resetValue:(int)resetValue withWrapper:(nonnull int (^)(int))wrapper;
+ (nonnull NSString *) compressToUriSafe:(nonnull NSString *)inputString;
- (nullable NSString *) decompressFromUriSafe:(nonnull NSString *)inputString;
@end
