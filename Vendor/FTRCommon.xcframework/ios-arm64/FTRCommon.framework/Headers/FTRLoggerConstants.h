//
//  FTRLoggerConstants.h
//  Common
//
//  Created by Dor Brauner on 23/07/2023.
//

#import <Foundation/Foundation.h>

#ifdef DEBUG
#define FTR_SDK_IS_IN_RELEASE_MODE FALSE
#else
#define FTR_SDK_IS_IN_RELEASE_MODE TRUE
#endif


#define FTR_SDK_LOG_LEVEL_OFF 0
#define FTR_SDK_LOG_LEVEL_ERROR 1
#define FTR_SDK_LOG_LEVEL_WARN 2
#define FTR_SDK_LOG_LEVEL_DEBUG 3
#define FTR_SDK_LOG_LEVEL_INFO 4
#define FTR_SDK_LOG_LEVEL_VERBOSE 5

#define FTR_SDK_LOG_MSG_PREFIX @"ForterSDK ->"
