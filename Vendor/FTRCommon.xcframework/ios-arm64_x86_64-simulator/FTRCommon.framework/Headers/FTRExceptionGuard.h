//
//  FTRExceptionGuard.h
//  FTRCommon
//
//  Copyright © 2026 Forter. All rights reserved.
//
#pragma once

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Runs a block inside an Objective-C @try/@catch so that an NSException raised by crash-prone
/// native APIs (NSJSONSerialization / KVC `setValue:forKey:` / CoreImage etc.) can never propagate
/// and crash the host app. Swift's `do/try/catch` cannot catch NSException — this bridge is the
/// only safe way to contain it.
@interface FTRExceptionGuard : NSObject

/// Executes @c block synchronously inside an @try/@catch.
/// @return YES if the block completed normally, NO if an NSException was caught and swallowed.
+ (BOOL)tryBlock:(NS_NOESCAPE void (^)(void))block NS_SWIFT_NAME(tryBlock(_:));

@end

NS_ASSUME_NONNULL_END
