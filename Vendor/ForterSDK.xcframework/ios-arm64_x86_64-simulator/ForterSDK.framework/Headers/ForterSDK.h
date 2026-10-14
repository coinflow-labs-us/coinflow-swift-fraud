//
//  ForterSDK.h
//  ForterSDK
//
//  Created by Or Polaczek on 23/06/2016.
//  Copyright © 2016 Forter. All rights reserved.
//

#pragma once

#import <Foundation/Foundation.h>
#import "FTRSDKPublicConstants.h"
#import "FTRSDKConfigurationKeys.h"
#import "ForterTokenListener.h"




#if FTR_SDK_UI_KIT_DEPENDENCY_ENABLED
#import "FTRSDKApplicationDelegate.h"
#import "FTRWebViewIntegration.h"

#endif

//! Project version number for ForterSDK.
FOUNDATION_EXPORT double ForterSDKVersionNumber;

//! Project version string for ForterSDK.
FOUNDATION_EXPORT const unsigned char ForterSDKVersionString[];


NS_ASSUME_NONNULL_BEGIN

@class FTRSDKConfiguration;

/**
 ForterSDK - Simple and lightweight toolkit that lets you integrate with Forter.
 
 Tracking user behaviour using the SDK is important for a successful integration. For more details please read our integration guide (Attached to the SDK binaries).
 */
@interface ForterSDK : NSObject

/** @name SDK Init and Config */

/**
 Retrive the ForterSDK shared instance.
 
 @return ForterSDK shared instance
 */
+ (instancetype)sharedInstance;

/**
 Set-up the ForterSDK with the provided FTRSDKConfiguration.
 
 @param configuration FTRSDKConfiguration object with the desired SDK configuration
 @return ForterSDK shared instance with the updated configuration
 */
+ (instancetype)setupWithConfig:(FTRSDKConfiguration *)configuration;

/**
 Set-up the ForterSDK with the provided siteid.
 
 @param siteId The Forter site id from the Forter Portal
 @return ForterSDK shared instance with the updated configuration
 */
+ (instancetype) setupWithSiteId:(nonnull NSString*) siteId;

/**
 Set-up the ForterSDK with the provided siteId.
 
 @param siteId The Forter site id from the Forter Portal
 @return ForterSDK shared instance
 */
+ (instancetype)setupWithDeviceUid:(NSString *)deviceUid siteId:(NSString *)siteId;
/**
 * Register for Forter token updates
 * YOU MUST CALL THIS METHOD RIGHT AFTER INITIALIZING THE SDK
 * It's highly recommended to register from application of your AppDelegate class
 *
 * @param listener The listener to register
 */
+ (void)registerForterTokenListener:(ForterTokenListener *)listener;

/**
 * Unregister Forter token updates
 *
 * @param listener The listener to unregister
 */
+ (void)unregisterForterTokenListener:(ForterTokenListener *)listener;

/**
 * Get the latest Forter token
 */
+ (NSString *)getForterToken:(NSError **)error;

/**
 Use this method to update the current FTRSDKConfiguration in the shared instance.
 
 @param configuration FTRSDKConfiguration object with the desired SDK configuration
 */
- (void)updateConfiguration:(FTRSDKConfiguration *)configuration;


/** @name Providing device and user identifiers */

/**
 Set the current device unique ID.
 @warning **THIS ID SHOULD BE PASSED LATER ON THROUGH THE ORDER API** (as `mobileUID`)
 
 @param deviceUid The unique device ID **as used by YOUR application**
 */
- (void)setDeviceUniqueIdentifier:(NSString *)deviceUid;

/**
 Set user accounts identifiers as they become available.
 Use *`Merchant`* when providing the account ID used by your system.
 See FTRSDKAccountIdType for all available account types.
 **Please do not provide [PII](https://en.wikipedia.org/wiki/Personally_identifiable_information) as IDs without hashing/encoding them first**.
 
 @param accountId The account identifier (encoded / hashed IF contains private information such as e-mail)
 @param accountType The type of the account id (See FTRSDKAccountIdType)
 
 @see [PII - Personally Identifiable Information](https://en.wikipedia.org/wiki/Personally_identifiable_information)
 */
- (void)setAccountIdentifier:(NSString *)accountId withType:(FTRSDKAccountIdType)accountType;


/** @name Navigation tracking */

/**
 Basic navigation track event upon screen change:
 
 @param screenName NSString with the screen's name. Screen name can be logical `Categories List` or the ViewController's class name if relevant ('CategoriesListViewController')
 @param navigationType FTRSDKNavigationType with the current screen's matching type
 @see [User behaviour tracking with the ForterSDK](http://www.forter.com/link_here).
 */
- (void)trackNavigation:(NSString*)screenName withType:(FTRSDKNavigationType)navigationType;

/**
 Detailed navigation track event upon screen change:
 
 Use this kind of track when the user views a certain category / item or when additional relevant info needs to be provided.
 
 @param screenName NSString with the screen's name. Screen name can be logical `Categories List` or the ViewController's class name if relevant ('CategoriesListViewController')
 @param navigationType FTRSDKNavigationType with the current screen's matching type
 @param pageId NSString of the current item ID (product ID / category ID)
 @param pageCategory NSString of the current item's category (e.g. 'Cameras')
 @param otherInfo NSString that contains any other relevant information
 @see [User behaviour tracking with the ForterSDK](http://www.forter.com/link_here).
 */
- (void)trackNavigation:(NSString*)screenName withType:(FTRSDKNavigationType)navigationType pageId:(NSString*)pageId pageCategory:(NSString*)pageCategory otherInfo:(NSString*)otherInfo;

/** @name User actions tracking */

/**
 Report a certain action performed by the user
 
 @param actionType The type of action the user performed (from the available FTRSDKActionType types)
 @see [User behaviour tracking with the ForterSDK](http://www.forter.com/link_here).
 */
- (void)trackAction:(FTRSDKActionType)actionType;

/**
 Report a certain action performed by the user
 
 @param actionType The type of action the user performed (from the available FTRSDKActionType types)
 @param actionMessage NSString with relevant data regarding the action (e.g. For the .AcceptedTOS track type -> whether the user agreed to receive newsletter email)
 @see [User behaviour tracking with the ForterSDK](http://www.forter.com/link_here).
 */
- (void)trackAction:(FTRSDKActionType)actionType withMessage:(NSString *)actionMessage;

/**
 Report a certain action performed by the user
 
 @param actionType The type of action the user performed (from the available FTRSDKActionType types)
 @param actionData NSDictionary containing relevant data (e.g. For the .PaymentInfo track type -> details about the payment info [response from InApp purchase, etc.])
 @see [User behaviour tracking with the ForterSDK](http://www.forter.com/link_here).
 */
- (void)trackAction:(FTRSDKActionType)actionType withData:(NSDictionary *)actionData;


/** @name Location updates */

// Not using CLLocationDegrees, in order to remove deps (CLLocation is a typeref to Double anyway).
/**
 This method shall be called upon every location update your app receives -
 Preferably from the didUpdateLocations delegate method.
 
 @param latitude The location latitude (double)
 @param longitude The location longitude (double)
 @param altitude The location altitude (double)
 */
- (void)didUpdateLocationLatitude:(double)latitude longitude:(double)longitude altitude:(double)altitude;


/** @name Miscellaneous */

/**
 Get the current SDK version signature (if needed, for debugging).
 
 @return NSString MD5 signature of the SDK version
 */
+ (NSString *)getSDKVersionSignature;

/**
 Enable developer logs for integration testing
 
 */
+ (void)setDevLogsEnabled:(BOOL)enabled;

/**
 Trigger immediate submission of all pending track data to our servers.
 
 @warning Use this method only if your app uses a custom SDK configuration.
 */
- (void)triggerSubmission;


/**
 * This method destroys the SDK.
 */
- (void) destroy;

@end


NS_ASSUME_NONNULL_END
/* ForterSDK_h */
