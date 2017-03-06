//
//  TTNetworkConfig.m
//  TTNetworkServer
//
//  Created by TengShuQiang on 2017/2/27.
//  Copyright © 2017年 TTeng. All rights reserved.
//

#import "TTNetworkConfig.h"

@implementation TTNetworkConfig
{
    NSMutableDictionary *_httpHeaderFields;
}

+ (TTNetworkConfig *)standardConfig {
    static TTNetworkConfig *_config = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _config = [[self alloc] init];
    });
    return _config;
}

- (instancetype)init{
    self = [super init];
    if (self) {
        _httpHeaderFields = @{}.mutableCopy;
    }
    return self;
}

- (NSTimeInterval)timeoutInterval {
    return _timeoutInterval ? : 30;
}

- (BOOL)networkActivityIndicatorEnabled {
    return _networkActivityIndicatorEnabled ? : YES;
}

- (void)setValue:(NSString *)value forHTTPHeaderField:(NSString *)field {
    [_httpHeaderFields setValue:value forKey:field];
}

- (NSDictionary<NSString *,NSString *> *)allHTTPHeaderFields {
    return _httpHeaderFields.copy;
}

@end
