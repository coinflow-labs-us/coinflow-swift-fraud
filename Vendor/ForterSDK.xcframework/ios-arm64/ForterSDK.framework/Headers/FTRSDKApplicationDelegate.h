//
//  FTRSDKApplicationDelegate.h
//  ForterSDK
//
//  Created by Or Polaczek on 12/09/2016.
//  Copyright © 2016 Forter. All rights reserved.
//
#pragma once

#import <UIKit/UIKit.h>

@interface FTRSDKApplicationDelegate : NSObject
/** Get the instance singleton */
+ (instancetype)sharedInstance;

/**
 Call this method from the [UIApplicationDelegate application:openURL:sourceApplication:annotation:] method
 of the AppDelegate for your app. It should be invoked for the proper use of the ForterSDK.
 
 @param application The application as passed to [UIApplicationDelegate application:openURL:sourceApplication:annotation:].
 @param url The URL as passed to [UIApplicationDelegate application:openURL:sourceApplication:annotation:].
 @param sourceApplication The sourceApplication as passed to [UIApplicationDelegate application:openURL:sourceApplication:annotation:].
 @param annotation The annotation as passed to [UIApplicationDelegate application:openURL:sourceApplication:annotation:].
 */
- (void)application:(UIApplication *)application
            openURL:(NSURL *)url
  sourceApplication:(NSString *)sourceApplication
         annotation:(id)annotation __attribute__((deprecated));


/**
 Call this method from the [UIApplicationDelegate application:openURL:options:] method (iOS 9+ only)
 of the AppDelegate for your app. It should be invoked for the proper use of the ForterSDK.
 
 @param app The application as passed to [UIApplicationDelegate application:openURL:options:].
 @param url The URL as passed to [UIApplicationDelegate application:openURL:options:].
 @param options The sourceApplication as passed to [UIApplicationDelegate application:openURL:options:].
 */
- (BOOL)application:(UIApplication *)app
            openURL:(NSURL *)url
            options:(NSDictionary<UIApplicationOpenURLOptionsKey,id> *)options;

/**
 Call this method from the [UIApplicationDelegate application:didFinishLaunchingWithOptions:] method
 of the AppDelegate for your app. It should be invoked for the proper use of the ForterSDK.
 
 @param application The application as passed to [UIApplicationDelegate application:didFinishLaunchingWithOptions:].
 @param launchOptions The launchOptions as passed to [UIApplicationDelegate application:didFinishLaunchingWithOptions:].
 */
- (void)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions;

/**
 Call this method from the [UIApplicationDelegate applicationDidBecomeActive:] method
 of the AppDelegate for your app. It should be invoked for the proper use of the ForterSDK.
 
 @param application The application as passed to [UIApplicationDelegate applicationDidBecomeActive:].
 */
- (void)applicationDidBecomeActive:(UIApplication *)application __attribute__((deprecated("applicationDidBecomeActive is deprecated and will be removed in future versions.")));

/**
 Call this method from the [UIApplicationDelegate applicationDidEnterBackground:] method
 of the AppDelegate for your app. It should be invoked for the proper use of the ForterSDK.
 
 @param application The application as passed to [UIApplicationDelegate applicationDidEnterBackground:].
 */

- (void)applicationDidEnterBackground:(UIApplication *)application __attribute__((deprecated("applicationDidEnterBackground is deprecated and will be removed in future versions.")));

@end
