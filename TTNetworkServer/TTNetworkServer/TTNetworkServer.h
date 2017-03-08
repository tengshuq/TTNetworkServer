//
//  TTNetworkServer.h
//  TTNetworkServer
//
//  Created by TengShuQiang on 2017/3/4.
//  Copyright © 2017年 TTeng. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "TTNetworkToast.h"
#import "TTNetworkConfig.h"

FOUNDATION_EXPORT void TTLog(NSString *format, ...) NS_FORMAT_FUNCTION(1, 2);
///网络状态变化时发出通知
FOUNDATION_EXPORT NSString *const TTNetworkStatusDidChangeNotification;

#ifndef kNetworkAvailable
#define kNetworkAvailable ([TTNetworkServer networkAvailable])
#endif

#ifndef kNetworkReachableViaWWAN
#define kNetworkReachableViaWWAN ([AFNetworkReachabilityManager sharedManager].reachableViaWWAN)
#endif

#ifndef kNetworkReachableViaWiFi
#define kNetworkReachableViaWiFi ([AFNetworkReachabilityManager sharedManager].reachableViaWiFi)
#endif

typedef NS_ENUM(NSInteger, TTNetworkStatusType) {
    TTNetworkStatusUnknow = 0,          ///< 未知网络
    TTNetworkStatusNotReachable,        ///< 无网络
    TTNetworkStatusReachableViaWWAN,    ///< 蜂窝网络
    TTNetworkStatusReachableViaWiFi,    ///< wifi
};

///请求成功的block
typedef void(^TTRequestSuccessBlock)(NSURLSessionDataTask *task, NSDictionary * responseObject);
///请求失败的block
typedef void(^TTRequestFailureBlock)(NSURLSessionDataTask *task, NSError *error);
///缓存的block
typedef void(^TTRequestCache)(NSDictionary *responseCache);
///上传的进度
typedef void (^TTRequestProgress)(NSProgress *progress);


@interface TTNetworkServer : NSObject

#pragma mark - 网络状况
#pragma mark -
///当前网络是否可用
+ (BOOL)networkAvailable;
///当前网络状态
+ (TTNetworkStatusType)networkStatusType;

#pragma mark - cookie 设置
#pragma mark -
///获取当前请求服务端返回的cookie
+ (void)getCookie:(NSURLSessionDataTask *)task;
/**
 手动设置客户端cookie(服务端的cookie在[TTNetworkConfig cookieEnabled]设置后自动启用)

 @param names   NSHTTPCookieName
 @param values  NSHTTPCookieValue
 @param url     NSHTTPCookieOriginURL
 @param expires NSHTTPCookieExpires
 @note          过多的cookie会造成请求头过大
 */
+ (void)setLocalCookieWithCookieName:(NSArray *)names values:(NSArray *)values originURL:(NSString *)url expires:(NSTimeInterval)expires;
///删除cookie
+ (void)clearCookie;

#pragma mark - Task cancel
#pragma mark -
///取消请求对应URL的请求，取消的请求不再回调数据
+ (void)cancelTaskWithURL:(NSString *)URL;
///取消所有请求,取消的请求不再回调数据
+ (void)cancelAllTask;

#pragma mark - 请求数据
#pragma mark -

/**
 普通的GET请求
 

 @param url        请求地址
 @param parameters 请求参数
 @param success    成功的回调
 @param failure    失败的回调
 @return           返回当前请求的Task
 @discussion       请求成功的数据会自动转为字典（包括XML数据），如果返回的数据无法转换，则返回@{@"result":reponse}，response为请求返回的数据，id类型
 */
+ (__kindof NSURLSessionTask *)GET:(NSString *)url
                        parameters:(NSDictionary *)parameters
                          succeess:(TTRequestSuccessBlock)success
                           failure:(TTRequestFailureBlock)failure;

/**
 普通的GET请求
 

 @param url         请求地址
 @param parameters  请求参数
 @param cacheResponse 缓存的回调
 @param success     成功的回调
 @param failure     失败的回调
 @return            返回当前请求的Task
 @discussion        请求成功的数据会自动转为字典（包括XML数据），如果返回的数据无法转换，则返回@{@"result":reponse}，response为请求返回的数据，id类型
 */
+ (__kindof NSURLSessionTask *)GET:(NSString *)url
                        parameters:(NSDictionary *)parameters
                     cacheResponse:(TTRequestCache)cacheResponse
                          succeess:(TTRequestSuccessBlock)success
                           failure:(TTRequestFailureBlock)failure;

/**
 普通的POST请求
 
 @param url         请求地址
 @param parameters  请求参数
 @param success     成功的回调
 @param failure     失败的回调
 @return            返回当前请求的Task
 @discussion        请求成功的数据会自动转为字典（包括XML数据），如果返回的数据无法转换，则返回@{@"result":reponse}的字典，response为请求返回的数据，id类型
 */
+ (__kindof NSURLSessionTask *)POST:(NSString *)url
                         parameters:(NSDictionary *)parameters
                            success:(TTRequestSuccessBlock)success
                            failure:(TTRequestFailureBlock)failure;

/**
 普通的GET请求

 
 @param url             请求地址
 @param parameters      请求参数
 @param cacheResponse   缓存的回调
 @param success         成功的回调
 @param failure         失败的回调
 @return                返回当前请求的Task
 @discussion            请求成功的数据会自动转为字典（包括XML数据），如果返回的数据无法转换，则返回@{@"result" : reponse}，response为请求返回的数据，id类型
 */
+ (__kindof NSURLSessionTask *)POST:(NSString *)url
                         parameters:(NSDictionary *)parameters
                      cacheResponse:(TTRequestCache)cacheResponse
                            success:(TTRequestSuccessBlock)success
                            failure:(TTRequestFailureBlock)failure;


/**
 上传文件

 @param url         上传地址
 @param parameters  上传参数
 @param name        文件对应服务器的name
 @param path        本地的沙盒路径
 @param progress    上传进度
 @param success     成功的回调
 @param failure     失败的回调
 @return            返回当前请求的Task
 */
+ (__kindof NSURLSessionTask *)uploadFileWithURL:(NSString *)url
                                      parameters:(NSDictionary *)parameters
                                            name:(NSString *)name
                                        filePath:(NSString *)path
                                        progress:(TTRequestProgress)progress
                                         success:(TTRequestSuccessBlock)success
                                         failure:(TTRequestFailureBlock)failure;

/**
 上传图片

 @param url         上传地址
 @param parameters  上传参数
 @param name        文件对应服务器的name
 @param size        需要压缩上传的图片大小（等比例压缩原图后得出的大小，单位为M）
 @param images      图片数组
 @param fileNames   图片文件名数组
 @param imageType   图片类型
 @param progress    上传的进度
 @param success     成功后的回调
 @param failure     失败后的回调
 @return            返回当前请求的Task
 @note              过多的图片压缩（数量和压缩比），可能会造成线程阻塞
 */
+ (__kindof NSURLSessionTask *)uploadImageWithURL:(NSString *)url
                                       parameters:(NSDictionary *)parameters
                                             name:(NSString *)name
                                      maxFileSize:(CGFloat)size
                                           images:(NSArray <UIImage *>*)images
                                        fileNames:(NSArray <NSString *>*)fileNames
                                        imageType:(NSString *)imageType
                                         progress:(TTRequestProgress)progress
                                          success:(TTRequestSuccessBlock)success
                                          failure:(TTRequestFailureBlock)failure;

@end

#pragma mark - 批量请求
#pragma mark -

@interface TTNetworkServer (TTNetworkBatch)

/**
 增加一个GET请求作为批量请求中的一个

 @param url         请求地址
 @param parameters  请求参数
 @param cacheResponse 是否缓存，不需要则输入nil
 @return            返回的TTNetworkServer 加入到数组中进行批量请求
 */
+ (TTNetworkServer *)addGET:(NSString *)url parameters:(NSDictionary *)parameters cacheResponse:(TTRequestCache)cacheResponse;

/**
 增加一个POST请求作为批量请求中的一个

 @param url         请求地址
 @param parameters  请求参数
 @param cacheResponse 是否缓存，不需要则输入nil
 @return            返回的TTNetworkServer 加入到数组中进行批量请求
 */
+ (TTNetworkServer *)addPOST:(NSString *)url parameters:(NSDictionary *)parameters cacheResponse:(TTRequestCache)cacheResponse;

/**
 发起批量请求，请求的结果会按request数组中的顺序加入回调的数组中

 @param request 需要请求的数组，数组至少包含2个以上内容
 @param cacheResponse 对应的缓存回调，如果有缓存则回调缓存的数据，若没有则回调[NSObject new]
 @param success 请求成功的回调，如果其中某一个请求发生错误，回调的结果对应位置为[NSObject new]的一个空内容
 @param failure 请求错误的回调，如果对应的位置没有error，则回调的结果为一个占位error
 @param task    task内容的回调，回调顺序对应加入的请求的顺序
 */
+ (void)startBatchRequest:(NSArray<TTNetworkServer *> *)request
            cacheResponse:(void(^)(NSArray<id> *))cacheResponse
                  success:(void(^)(NSArray<id> *))success
                  failure:(void(^)(NSArray<NSError *> *))failure
                     task:(void(^)(NSArray<NSURLSessionDataTask *> *))task;

@end

#pragma mark - 网络缓存
#pragma mark -

@interface TTNetworkServer (TTNetworkCache)

///获取所有缓存的大小 单位：bytes
+ (NSUInteger)allCacheSize;

///清除所有缓存
+ (void)clearCache;

/**
 清除所有缓存，回调清除的过程和结果

 @param progress 清除过程的回调
 @param handler  清除结果的回调
 */
+ (void)clearCacheWithProgress:(void(^)(int removedCount, int totalCount))progress
                    completion:(void(^)(BOOL error))handler;

@end

#pragma mark - 控制器设置
#pragma mark -

@interface UIViewController (TTNetwork)

///离开页面时取消当前页面上所有未完成的请求,默认为NO
- (void)cancelAllTasksWhileViewDidDisappear:(BOOL)cancel;

@end

