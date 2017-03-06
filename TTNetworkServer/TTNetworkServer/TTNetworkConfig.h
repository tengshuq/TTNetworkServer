//
//  TTNetworkConfig.h
//  TTNetworkServer
//
//  Created by TengShuQiang on 2017/2/27.
//  Copyright © 2017年 TTeng. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, TTNetworkRequestSerializer) {
    TTNetworkRequestSerializerHTTP = 0, ///< 请求数据格式HTTP
    TTNetworkRequestSerializerJSON      ///< 请求数据格式JSON
};

typedef NS_ENUM(NSInteger, TTNetworkReponseSerializer) {
    TTNetworkReponseSerializerHTTP = 0, ///< 返回的数据格式HTTP
    TTNetworkReponseSerializerJSON,     ///< 返回数据格式为JSON
    TTNetworkReponseSerializerXML       ///< 返回的数据格式为XML
};

@interface TTNetworkConfig : NSObject

///请求超时时间，默认30s
@property (nonatomic, assign) NSTimeInterval timeoutInterval;

///默认为TTNetworkRequestSerializerHTTP
@property (nonatomic, assign) TTNetworkRequestSerializer requestSerializer;

///
@property (nonatomic, assign) TTNetworkReponseSerializer responseSerializer __attribute__((deprecated("不用设置，会自动将HTTP、JSON、XML转换为可用的JSON格式")));

///需要的公共请求参数（比如时间戳、版本号什么的）
@property (nonatomic, strong) NSDictionary *commonParameters;

///根地址
@property (nonatomic, copy) NSString *baseURL;

///所有请求头信息
@property (nonatomic, readonly, copy) NSDictionary<NSString *, NSString *> *allHTTPHeaderFields;

///离开页面时取消当前页面上所有未完成的请求
@property (nonatomic, assign) BOOL cancelAllTasksWhileViewDidDisappear;

///是否显示转动的小菊花 默认为YES
@property (nonatomic, assign) BOOL networkActivityIndicatorEnabled;

/**
 是否使用cookie,默认为NO
 @discussion 一般的使用情况：登录时候获取cookie（需要在登录请求成功的回调里面手动调用[TTNetworkServer getCookie]），退出的时候清除cookie(需要手动调用[TTNetworkServer clearCookie])
 */
@property (nonatomic, assign) BOOL cookieEnabled;

///打印信息
@property (nonatomic, assign) BOOL debugLogEnabled;

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;
+ (instancetype)standardConfig;
///设置请求头
- (void)setValue:(NSString *)value forHTTPHeaderField:(NSString *)field;

@end
