//
//  MockObject.h
//  FTRCommonTests
//
//  Created by Dor Brauner on 18/12/2023.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface MockObject : NSObject

+ (void)mockMethodWithError:(NSError**) error;

@end

NS_ASSUME_NONNULL_END
