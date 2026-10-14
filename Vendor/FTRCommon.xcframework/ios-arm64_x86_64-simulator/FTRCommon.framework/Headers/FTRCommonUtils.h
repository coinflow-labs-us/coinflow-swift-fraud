//
//  FTRCommonUtils.h
//  Common
//
//  Created by Dor Brauner on 25/07/2023.
//

#import <Foundation/Foundation.h>


@interface FTRCommonUtils : NSObject
+ (NSString *)getEmptyStringIfNilForString:(NSString *)string;
+ (NSString *)replaceOccurrencesOfString:(NSString *)string withString:(NSString *)newString inString:(NSString *)originalString;
+ (NSString *)boolToString:(BOOL)boolean;
+ (NSString *)dateToString:(NSDate *)date;
+ (long long)timeIntervalToLong:(NSTimeInterval)time;
+ (NSString *)doubleToString:(double)number;
+ (NSString *)generateGUID;
+ (int64_t)currentTimestamp;
+ (id)toJsonNullable:(id)data;
+ (NSData *)objToJson:(NSDictionary *)data;
+ (NSData *)objToJson:(id)data options:(NSJSONWritingOptions)opt;
+ (NSString *)dataToString:(NSData *)data;
+ (NSString *)objToJSONString:(NSDictionary *)data;
+ (NSString *)nsDictionary:(NSDictionary *)data toUrl:(NSString *)url;
+ (NSString *)sha1:(NSString *)string;
+ (NSData *)base64ToData:(NSString *)string;
+ (NSString *)base64ToString:(NSString *)string;
+ (NSString *)stringToBase64:(NSString *)string;
+ (NSString *)base64ToHexString:(NSString *)string;
+ (NSString *)base64ToHexStringOld:(NSString *)string;
+ (void)raiseFatalError:(NSString *)reason;
@end


