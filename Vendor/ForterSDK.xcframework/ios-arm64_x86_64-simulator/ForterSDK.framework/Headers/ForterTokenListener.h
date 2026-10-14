//
//  ForterTokenListener.h
//  ForterSDK
//
//  Created by Moshe Krush on 11/09/2023.
//  Copyright © 2023 Forter. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface ForterTokenListener : NSObject

- (instancetype)initWithUpdatesHandler:(nonnull void (^)(NSString * _Nonnull __strong))onUpdate;

@end

NS_ASSUME_NONNULL_END
