//
//  TTNetworkServer.m
//  TTNetworkServer
//
//  Created by TengShuQiang on 2017/3/4.
//  Copyright © 2017年 TTeng. All rights reserved.
//

#import "TTNetworkServer.h"
#import "AFNetworking.h"
#import "AFNetworkActivityIndicatorManager.h"
#import "YYCache.h"
#import <pthread/pthread.h>
#import <objc/runtime.h>
#include <CommonCrypto/CommonCrypto.h>

#define force_inline __inline__ __attribute__((always_inline))

void TTLog(NSString *format, ...) {
#ifdef DEBUG
    if (![TTNetworkConfig standardConfig].debugLogEnabled) {
        return;
    }
    va_list args;
    va_start(args, format);
    NSString *string = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);
    
    NSString *strFormat = [NSString stringWithFormat:@"%@",string];
    NSLog(@"%@", strFormat);
    
#endif
}
NSString *const TTNetworkStatusDidChangeNotification = @"AFNetworkingReachabilityDidChangeNotification";

@interface NSString (AddForMD5)
@end
@implementation NSString (AddForMD5)

- (NSString *)tt_md5String {
    NSData *data = [self dataUsingEncoding:NSUTF8StringEncoding];
    unsigned char result[CC_MD2_DIGEST_LENGTH];
    CC_MD2(data.bytes, (CC_LONG)data.length, result);
    return [NSString stringWithFormat:
            @"%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x",
            result[0], result[1], result[2], result[3],
            result[4], result[5], result[6], result[7],
            result[8], result[9], result[10], result[11],
            result[12], result[13], result[14], result[15]
            ];
}

@end

#pragma mark - 来自YYKit的XML解析
#pragma mark -

@interface _YYXMLDictionaryParser : NSObject <NSXMLParserDelegate>
@end

@implementation _YYXMLDictionaryParser {
    NSMutableDictionary *_root;
    NSMutableArray *_stack;
    NSMutableString *_text;
}

- (instancetype)initWithData:(NSData *)data {
    self = super.init;
    NSXMLParser *parser = [[NSXMLParser alloc] initWithData:data];
    [parser setDelegate:self];
    [parser parse];
    return self;
}

- (instancetype)initWithString:(NSString *)xml {
    NSData *data = [xml dataUsingEncoding:NSUTF8StringEncoding];
    return [self initWithData:data];
}

- (NSDictionary *)result {
    return _root;
}

#pragma mark - NSXMLParserDelegate

#define XMLText @"_text"
#define XMLName @"_name"
#define XMLPref @"_"

- (void)textEnd {
    _text = [_text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]].mutableCopy;
    if (_text.length) {
        NSMutableDictionary *top = _stack.lastObject;
        id existing = top[XMLText];
        if ([existing isKindOfClass:[NSArray class]]) {
            [existing addObject:_text];
        } else if (existing) {
            top[XMLText] = [@[existing, _text] mutableCopy];
        } else {
            top[XMLText] = _text;
        }
    }
    _text = nil;
}

- (void)parser:(__unused NSXMLParser *)parser didStartElement:(NSString *)elementName namespaceURI:(__unused NSString *)namespaceURI qualifiedName:(__unused NSString *)qName attributes:(NSDictionary *)attributeDict {
    [self textEnd];
    
    NSMutableDictionary *node = [NSMutableDictionary new];
    if (!_root) node[XMLName] = elementName;
    if (attributeDict.count) [node addEntriesFromDictionary:attributeDict];
    
    if (_root) {
        NSMutableDictionary *top = _stack.lastObject;
        id existing = top[elementName];
        if ([existing isKindOfClass:[NSArray class]]) {
            [existing addObject:node];
        } else if (existing) {
            top[elementName] = [@[existing, node] mutableCopy];
        } else {
            top[elementName] = node;
        }
        [_stack addObject:node];
    } else {
        _root = node;
        _stack = [NSMutableArray arrayWithObject:node];
    }
}

- (void)parser:(__unused NSXMLParser *)parser didEndElement:(__unused NSString *)elementName namespaceURI:(__unused NSString *)namespaceURI qualifiedName:(__unused NSString *)qName {
    [self textEnd];
    
    NSMutableDictionary *top = _stack.lastObject;
    [_stack removeLastObject];
    
    NSMutableDictionary *left = top.mutableCopy;
    [left removeObjectsForKeys:@[XMLText, XMLName]];
    for (NSString *key in left.allKeys) {
        [left removeObjectForKey:key];
        if ([key hasPrefix:XMLPref]) {
            left[[key substringFromIndex:XMLPref.length]] = top[key];
        }
    }
    if (left.count) return;
    
    NSMutableDictionary *children = top.mutableCopy;
    [children removeObjectsForKeys:@[XMLText, XMLName]];
    for (NSString *key in children.allKeys) {
        if ([key hasPrefix:XMLPref]) {
            [children removeObjectForKey:key];
        }
    }
    if (children.count) return;
    
    NSMutableDictionary *topNew = _stack.lastObject;
    NSString *nodeName = top[XMLName];
    if (!nodeName) {
        for (NSString *name in topNew) {
            id object = topNew[name];
            if (object == top) {
                nodeName = name; break;
            } else if ([object isKindOfClass:[NSArray class]] && [object containsObject:top]) {
                nodeName = name; break;
            }
        }
    }
    if (!nodeName) return;
    
    id inner = top[XMLText];
    if ([inner isKindOfClass:[NSArray class]]) {
        inner = [inner componentsJoinedByString:@"\n"];
    }
    if (!inner) return;
    
    id parent = topNew[nodeName];
    if ([parent isKindOfClass:[NSArray class]]) {
        NSArray *parentAsArray = parent;
        parent[parentAsArray.count - 1] = inner;
    } else {
        topNew[nodeName] = inner;
    }
}

- (void)parser:(__unused NSXMLParser *)parser foundCharacters:(NSString *)string {
    if (_text) [_text appendString:string];
    else _text = [NSMutableString stringWithString:string];
}

- (void)parser:(__unused NSXMLParser *)parser foundCDATA:(NSData *)CDATABlock {
    NSString *string = [[NSString alloc] initWithData:CDATABlock encoding:NSUTF8StringEncoding];
    if (_text) [_text appendString:string];
    else _text = [NSMutableString stringWithString:string];
}

#undef XMLText
#undef XMLName
#undef XMLPref
@end

#pragma mark - 缓存部分
#pragma mark -

@interface _TTNetworkCache : NSObject
///设置缓存
+ (void)setCache:(id)httpData withURL:(NSString *)url parameters:(NSDictionary *)para;
///获取缓存
+ (id)cacheForURL:(NSString *)url parameters:(NSDictionary *)para;
@end

static NSString *const NetworkResponseCache = @"TTNetworkResponseCache";
@implementation _TTNetworkCache

+ (YYCache *)standardCache {
    static YYCache *_cache = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _cache = [YYCache cacheWithName:NetworkResponseCache];
    });
    return _cache;
}

//设置缓存
+ (void)setCache:(id)httpData withURL:(NSString *)url parameters:(NSDictionary *)para {
    NSString *key = [self cacheKeyWithURL:url parameters:para] ;
    [[self standardCache] setObject:httpData forKey:key withBlock:nil];
}
//获取缓存
+ (id)cacheForURL:(NSString *)url parameters:(NSDictionary *)para {
    NSString *key = [self cacheKeyWithURL:url parameters:para];
    return [[self standardCache] objectForKey:key];
}
+ (NSString *)cacheKeyWithURL:(NSString *)url parameters:(NSDictionary *)para {
    if (!para) return [url tt_md5String];
    NSData *paraData = [NSJSONSerialization dataWithJSONObject:para options:NSJSONWritingPrettyPrinted error:nil];
    NSString *paraString = [[NSString alloc] initWithData:paraData encoding:NSUTF8StringEncoding];
    NSString *key = [[NSString stringWithFormat:@"%@%@",url,paraString] tt_md5String];
    return key;
}

@end

#pragma mark - TTNetworkServer
#pragma mark -
static NSString *const TTNetworkDefaultCooke = @"TTNetworkDefaultCooke";
static NSMutableArray <NSURLSessionTask *>*_allSessionTask;
static pthread_mutex_t _mutexLock;
static AFHTTPSessionManager *_sessionManager;
static TTNetworkStatusType _currentNetworkStatus;

@implementation TTNetworkServer

- (void)dealloc {
#if (defined(__IPHONE_OS_VERSION_MIN_REQUIRED) && __IPHONE_OS_VERSION_MIN_REQUIRED < 90000)
    [[NSNotificationCenter defaultCenter] removeObserver:self];
#endif
}

+ (void)load {
    _allSessionTask = @[].mutableCopy;
    pthread_mutex_init(&_mutexLock, NULL);
    [[AFNetworkReachabilityManager sharedManager] startMonitoring];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(networkStatusChanged:) name:AFNetworkingReachabilityDidChangeNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(sessionInvalidate) name:AFURLSessionDidInvalidateNotification object:nil];
}

+ (void)sessionInvalidate {
    _sessionManager = nil;
}

+ (AFHTTPSessionManager *)sessionManager {
    //单例的使用 http://blog.csdn.net/zhzmaren/article/details/53021384
    
    static AFHTTPSessionManager *_sessionManager = nil;
    TTNetworkConfig *config = [TTNetworkConfig standardConfig];
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _sessionManager = [[AFHTTPSessionManager alloc] initWithBaseURL:[NSURL URLWithString:config.baseURL]];
        _sessionManager.responseSerializer = [AFHTTPResponseSerializer serializer];
        _sessionManager.responseSerializer.acceptableContentTypes = [NSSet setWithObjects:@"application/json", @"text/html", @"text/json", @"text/plain", @"text/javascript", @"text/xml", @"image/*", nil];
        _sessionManager.requestSerializer.timeoutInterval = config.timeoutInterval;
        [config.allHTTPHeaderFields enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull key, NSString * _Nonnull obj, BOOL * _Nonnull stop) {
            [_sessionManager.requestSerializer setValue:obj forHTTPHeaderField:key];
        }];
        _sessionManager.requestSerializer = config.requestSerializer == 0 ? [AFHTTPRequestSerializer serializer] : [AFJSONRequestSerializer serializer];
        
    });
    return _sessionManager;
}

#pragma mark 网络状态

///当前网络是否可用
+ (BOOL)networkAvailable {
    return [AFNetworkReachabilityManager manager].reachable;
}
///当前网络状态
+ (TTNetworkStatusType)networkStatusType {
    return _currentNetworkStatus;
}

+ (void)networkStatusChanged:(NSNotification *)noti {
    NSNumber *number = [noti.userInfo objectForKey:AFNetworkingReachabilityNotificationStatusItem];
    [self convertAFNetworkStatus:number];
    [[NSNotificationCenter defaultCenter] postNotificationName:TTNetworkStatusDidChangeNotification object:nil];
}

+ (TTNetworkStatusType)convertAFNetworkStatus:(NSNumber *)status {
    switch ([status integerValue]) {
        case -1: return _currentNetworkStatus = TTNetworkStatusUnknow;
        case  0: return _currentNetworkStatus = TTNetworkStatusNotReachable;
        case  1: return _currentNetworkStatus = TTNetworkStatusReachableViaWWAN;
        case  2: return _currentNetworkStatus = TTNetworkStatusReachableViaWiFi;
        default: return _currentNetworkStatus = TTNetworkStatusUnknow;
    }
}

#pragma mark cookie设置

///获取cookie
+ (void)getCookie:(NSURLSessionDataTask *)task {
    //获取并且保存cookies
    NSArray *cookies = [[NSHTTPCookieStorage sharedHTTPCookieStorage] cookiesForURL: task.currentRequest.URL];
    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:cookies];
    [[NSUserDefaults standardUserDefaults] setObject:data forKey:TTNetworkDefaultCooke];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

static force_inline void setCookie(){
    NSData *cookiesdata = [[NSUserDefaults standardUserDefaults] objectForKey:TTNetworkDefaultCooke];
    if([cookiesdata length]) {
        NSArray *cookies = [NSKeyedUnarchiver unarchiveObjectWithData:cookiesdata];
        NSHTTPCookie *cookie;
        for (cookie in cookies) {
            [[NSHTTPCookieStorage sharedHTTPCookieStorage] setCookie:cookie];
        }
    }
}

+ (void)setLocalCookieWithCookieName:(NSArray *)names values:(NSArray *)values originURL:(NSString *)url expires:(NSTimeInterval)expires {
#if DEBUG
    NSAssert(names.count == values.count && names.count != 0, @"name和value须一一对应且不为空");
#else
    if (names.count != values.count || names.count == 0) return;
#endif
    for (int i = 0; i < names.count; i++) {
        NSDictionary *property = @{NSHTTPCookieName :names[i],
                                   NSHTTPCookieValue : values[i],
                                   NSHTTPCookieOriginURL : url,
                                   NSHTTPCookieExpires : [NSDate dateWithTimeIntervalSinceNow:expires]};
        NSHTTPCookie *cookie = [NSHTTPCookie cookieWithProperties:property];
        [[NSHTTPCookieStorage sharedHTTPCookieStorage] setCookie:cookie];
    }
}

///清除cookie
+ (void)clearCookie {
    NSData *cookiesdata = [[NSUserDefaults standardUserDefaults] objectForKey:TTNetworkDefaultCooke];
    if([cookiesdata length]) {
        NSArray *cookies = [NSKeyedUnarchiver unarchiveObjectWithData:cookiesdata];
        NSHTTPCookie *cookie;
        for (cookie in cookies) {
            [[NSHTTPCookieStorage sharedHTTPCookieStorage] deleteCookie:cookie];
            [[NSURLCache sharedURLCache] removeAllCachedResponses];
            [[NSUserDefaults standardUserDefaults] removeObjectForKey:TTNetworkDefaultCooke];
            [[NSUserDefaults standardUserDefaults] synchronize];
        }
    }
}

#pragma mark 基本请求

///取消请求
+ (void)cancelTaskWithURL:(NSString *)URL {
    if (!URL || _allSessionTask.count == 0) return;
    pthread_mutex_lock(&_mutexLock);
    [_allSessionTask enumerateObjectsUsingBlock:^(NSURLSessionTask * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if ([obj.currentRequest.URL.absoluteString containsString:URL]) {
            [obj cancel];
            [_allSessionTask removeObject:obj];
            //*stop = YES; //考虑在一个时间段向同一URL发起多次请求的情况
        }
    }];
    pthread_mutex_unlock(&_mutexLock);
}
///取消所有请求
+ (void)cancelAllTask {
    if (_allSessionTask.count == 0) return;
    pthread_mutex_lock(&_mutexLock);
    [_allSessionTask enumerateObjectsUsingBlock:^(NSURLSessionTask * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        [obj cancel];
    }];
    [_allSessionTask removeAllObjects];
    pthread_mutex_unlock(&_mutexLock);
}

static force_inline void addSessionDataTask(__unsafe_unretained NSURLSessionDataTask *task){
    pthread_mutex_lock(&_mutexLock);
    [_allSessionTask addObject:task];
    pthread_mutex_unlock(&_mutexLock);
}

static force_inline void removeSessionDataTask(__unsafe_unretained NSURLSessionDataTask *task){
    pthread_mutex_lock(&_mutexLock);
    [_allSessionTask removeObject:task];
    pthread_mutex_unlock(&_mutexLock);
}

static force_inline void networkCookieConfig(){
    [TTNetworkConfig standardConfig].cookieEnabled ? setCookie() : nil;
}

static force_inline void networkHeaderValuesConfig() {
    [[TTNetworkConfig standardConfig].allHTTPHeaderFields enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull key, NSString * _Nonnull obj, BOOL * _Nonnull stop) {
        [[TTNetworkServer sessionManager].requestSerializer setValue:obj forHTTPHeaderField:key];
    }];
}

static force_inline void showNetworkActivityIndicator(){
    [AFNetworkActivityIndicatorManager sharedManager].enabled = [TTNetworkConfig standardConfig].networkActivityIndicatorEnabled;
}

static force_inline void hideNetworkActivityIndicator(){
    [AFNetworkActivityIndicatorManager sharedManager].enabled = NO;
}

+ (void)logRequestCancel:(NSURLSessionDataTask *)task para:(NSDictionary *)para {
    TTLog(@"\n=================================\n请求的地址是：%@\n上传的参数为：%@\n!!!!该请求已取消!!!!\n=================================\n",task.currentRequest.URL,para);
}

+ (void)logRequestSuccess:(NSURLSessionDataTask *)task para:(NSDictionary *)para response:(NSDictionary *)response {
    TTLog(@"\n=================================\n请求的地址是：%@\n上传的参数为：%@\n返回的数据:dic:%@\n=================================\n",task.currentRequest.URL,para,response);
}

+ (void)logRequestFailure:(NSURLSessionDataTask *)task para:(NSDictionary *)para error:(NSError *)error {
    TTLog(@"\n=================================\n请求的地址是：%@\n上传的参数为：%@\n返回的错误:error:%@\n=================================\n",task.currentRequest.URL,para,error);
}

+ (NSDictionary *)addCommonParameters:(NSDictionary *)parameters{
    NSMutableDictionary *mDic = [NSMutableDictionary dictionaryWithDictionary:parameters];
    if ([TTNetworkConfig standardConfig].commonParameters) {
        [mDic addEntriesFromDictionary:[TTNetworkConfig standardConfig].commonParameters];
    }
    return mDic.copy;
}

+ (NSDictionary *)convertResponse:(id)response withTask:(NSURLSessionDataTask *)task{
    if (!response) return @{@"result":@"没有任何数据"};
    NSData *data = [NSData dataWithData:response];
    if ([task.response.textEncodingName compare:@"gbk" options:NSCaseInsensitiveSearch] == NSOrderedSame) {
        NSStringEncoding enc =CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingGB_18030_2000);
        NSString *GBKString = [[NSString alloc]initWithData:response encoding:enc];
        data = [GBKString dataUsingEncoding:NSUTF8StringEncoding];
    }
    if (!data) {
        TTLog(@"%@,返回的数据无法转换为可用JSON格式，请检查",task.currentRequest.URL);
        return @{@"result":response};
    }
    NSDictionary *dic;
    dic = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:nil];
    if ([NSJSONSerialization isValidJSONObject:dic]) {
        return dic;
    }
    _YYXMLDictionaryParser *parser = [[_YYXMLDictionaryParser alloc] initWithData:data];
    dic = [parser result];
    if ([NSJSONSerialization isValidJSONObject:dic]) {
        return dic;
    }
    // 这样的 https://stackoverflow.com/questions/16961025/nsjsonserialization-nsjsonreadingallowfragments-reading
    if (![NSJSONSerialization isValidJSONObject:data]) {
        NSString *res = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:nil];
        return @{@"result":res ? : @"没有可用的数据"};
    }
    TTLog(@"%@,返回的数据无法转换为可用JSON格式，请检查",task.currentRequest.URL);
    return @{@"result":response};
}

+ (NSURLSessionTask *)GET:(NSString *)url
               parameters:(NSDictionary *)parameters
                 succeess:(TTRequestSuccessBlock)success
                  failure:(TTRequestFailureBlock)failure {
    return [self GET:url parameters:parameters cacheResponse:nil succeess:success failure:failure];
}

+ (NSURLSessionTask *)GET:(NSString *)url
               parameters:(NSDictionary *)parameters
            cacheResponse:(TTRequestCache)cacheResponse
                 succeess:(TTRequestSuccessBlock)success
                  failure:(TTRequestFailureBlock)failure {
    
    cacheResponse ? cacheResponse([_TTNetworkCache cacheForURL:url parameters:parameters]) : nil;
    networkCookieConfig();
    networkHeaderValuesConfig();
    showNetworkActivityIndicator();
    NSDictionary *newParam = [self addCommonParameters:parameters];
    NSURLSessionDataTask *sessionTask = [[self sessionManager] GET:url parameters:newParam progress:^(NSProgress * _Nonnull downloadProgress) {
        
    } success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
        removeSessionDataTask(task);
        hideNetworkActivityIndicator();
        NSDictionary *result = [self convertResponse:responseObject withTask:task];
        cacheResponse ? [_TTNetworkCache setCache:result withURL:url parameters:parameters] : nil;
        success ? success(task, result) : nil;
        [self logRequestSuccess:task para:newParam response:result];
        
    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
        removeSessionDataTask(task);
        hideNetworkActivityIndicator();
        if (error.code == -999 ) {
            [self logRequestCancel:task para:newParam];
            return ;
        } else {
            failure ? failure(task,error) : nil;
            [self logRequestFailure:task para:newParam error:error];
        }
    }];
    addSessionDataTask(sessionTask);
    return sessionTask;
}

+ (NSURLSessionTask *)POST:(NSString *)url
                parameters:(NSDictionary *)parameters
                   success:(TTRequestSuccessBlock)success
                   failure:(TTRequestFailureBlock)failure {
    return [self POST:url parameters:parameters cacheResponse:nil success:success failure:failure];
}

+ (NSURLSessionTask *)POST:(NSString *)url
                parameters:(NSDictionary *)parameters
             cacheResponse:(TTRequestCache)cacheResponse
                   success:(TTRequestSuccessBlock)success
                   failure:(TTRequestFailureBlock)failure {
    
    cacheResponse ? cacheResponse([_TTNetworkCache cacheForURL:url parameters:parameters]) : nil;
    networkCookieConfig();
    networkHeaderValuesConfig();
    showNetworkActivityIndicator();
    NSDictionary *newParam = [self addCommonParameters:parameters];
    NSURLSessionDataTask *sessionTask = [[self sessionManager] POST:url parameters:newParam progress:^(NSProgress * _Nonnull uploadProgress) {
        
    } success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
        hideNetworkActivityIndicator();
        removeSessionDataTask(task);
        NSDictionary *result = [self convertResponse:responseObject withTask:task];
        cacheResponse ? [_TTNetworkCache setCache:result withURL:url parameters:parameters] : nil;
        success ? success(task, result) : nil;
        [self logRequestSuccess:task para:newParam response:result];
        
    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
        removeSessionDataTask(task);
        hideNetworkActivityIndicator();
        if (error.code == -999) {
            [self logRequestCancel:task para:newParam];
            return ;
        } else {
            failure ? failure(task,error) : nil;
            [self logRequestFailure:task para:newParam error:error];
        }
    }];
    addSessionDataTask(sessionTask);
    return sessionTask;
}

+ (NSURLSessionTask *)uploadFileWithURL:(NSString *)url
                             parameters:(NSDictionary *)parameters
                                   name:(NSString *)name
                               filePath:(NSString *)path
                               progress:(TTRequestProgress)progress
                                success:(TTRequestSuccessBlock)success
                                failure:(TTRequestFailureBlock)failure {
    networkCookieConfig();
    networkHeaderValuesConfig();
    showNetworkActivityIndicator();
    NSDictionary *newParam = [self addCommonParameters:parameters];
    NSURLSessionDataTask *sessionTask = [[self sessionManager] POST:url parameters:newParam constructingBodyWithBlock:^(id<AFMultipartFormData>  _Nonnull formData) {
        NSError *error = nil;
        [formData appendPartWithFileURL:[NSURL URLWithString:path] name:name error:&error];
        (failure && error) ? failure(nil,error) : nil;
        error ? TTLog(@"上传失败") : nil;
    } progress:^(NSProgress * _Nonnull uploadProgress) {
        dispatch_sync(dispatch_get_main_queue(), ^{
            progress ? progress(uploadProgress) : nil;
        });
    } success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
        hideNetworkActivityIndicator();
        NSDictionary *result = [self convertResponse:responseObject withTask:task];
        success ? success(task, result) : nil;
        removeSessionDataTask(task);
        [self logRequestSuccess:task para:newParam response:result];
        
    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
        removeSessionDataTask(task);
        hideNetworkActivityIndicator();
        if (error.code == -999 ) {
            [self logRequestCancel:task para:newParam];
            return ;
        } else {
            failure ? failure(task,error) : nil;
            [self logRequestFailure:task para:newParam error:error];
        }
    }];
    addSessionDataTask(sessionTask);
    return sessionTask;
}

+ (NSURLSessionTask *)uploadImageWithURL:(NSString *)url
                              parameters:(NSDictionary *)parameters
                                    name:(NSArray *)names
                             maxFileSize:(CGFloat)size
                                  images:(NSArray <UIImage *>*)images
                               fileNames:(NSArray <NSString *>*)fileNames
                               imageType:(NSString *)imageType
                                progress:(TTRequestProgress)progress
                                 success:(TTRequestSuccessBlock)success
                                 failure:(TTRequestFailureBlock)failure {
    NSAssert(images.count == fileNames.count, @"图片和文件名数量须相等");
    NSAssert(images.count != 0, @"图片不能为空");
    networkCookieConfig();
    networkHeaderValuesConfig();
    showNetworkActivityIndicator();
    NSDictionary *newParam = [self addCommonParameters:parameters];
    __block NSURLSessionDataTask *sessionTask;
    NSMutableArray *mArr = @[].mutableCopy;
    if (size && size > 0) {
        dispatch_group_t group = dispatch_group_create();
        dispatch_group_async(group, dispatch_get_global_queue(0, 0), ^{
            for (int i = 0; i < images.count; i++) {
                dispatch_group_enter(group);
                NSData *data = [self zipImageWithImage:images[i] maxSize:size];
                pthread_mutex_lock(&_mutexLock);
                [mArr addObject:data];
                pthread_mutex_unlock(&_mutexLock);
                dispatch_group_leave(group);
            }
        });
        dispatch_group_notify(group, dispatch_get_global_queue(0, 0), ^{
            sessionTask = [self _uploadImageWithURL:url para:newParam name:names images:mArr fileNames:fileNames imageType:imageType progress:progress success:success failure:failure];
            addSessionDataTask(sessionTask);
        });
    } else {
        sessionTask = [self _uploadImageWithURL:url para:newParam name:names images:mArr fileNames:fileNames imageType:imageType progress:progress success:success failure:failure];
        addSessionDataTask(sessionTask);
    }
    
    return sessionTask;
}

+ (__kindof NSURLSessionTask *)_uploadImageWithURL:(NSString *)url
                                              para:(NSDictionary *)para
                                              name:(NSArray *)names
                                            images:(NSArray <NSData *>*)images
                                         fileNames:(NSArray <NSString *>*)fileNames
                                         imageType:(NSString *)imageType
                                          progress:(TTRequestProgress)progress
                                           success:(TTRequestSuccessBlock)success
                                           failure:(TTRequestFailureBlock)failure{
    NSURLSessionDataTask *sessionTask = [[self sessionManager] POST:url parameters:para constructingBodyWithBlock:^(id<AFMultipartFormData>  _Nonnull formData) {
        for (int i = 0; i < images.count; i++) {
            [formData appendPartWithFileData:images[i] name:names[i] fileName:fileNames[i] mimeType:imageType ? : [NSString stringWithFormat:@"image/jpg"]];
        }
    } progress:^(NSProgress * _Nonnull uploadProgress) {
        dispatch_sync(dispatch_get_main_queue(), ^{
            progress ? progress(uploadProgress) : nil;
        });
    } success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
        hideNetworkActivityIndicator();
        removeSessionDataTask(task);
        NSDictionary *result = [self convertResponse:responseObject withTask:task];
        success ? success(task, result) : nil;
        [self logRequestSuccess:task para:para response:result];
        
    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
        removeSessionDataTask(task);
        hideNetworkActivityIndicator();
        if (error.code == -999 ) {
            [self logRequestCancel:task para:para];
            return ;
        } else {
            failure ? failure(task,error) : nil;
            [self logRequestFailure:task para:para error:error];
        }
    }];
    return sessionTask;
}

+ (NSData *)zipImageWithImage:(UIImage *)image maxSize:(CGFloat)size{
    if (!image) {
        return nil;
    }
    CGFloat maxFileSize = size*1024*1024;
    CGFloat compression = 0.9f;
    NSData *compressedData = UIImageJPEGRepresentation(image, compression);
    
    while ([compressedData length] > maxFileSize) {
        compression *= 0.9;
        compressedData = UIImageJPEGRepresentation([self compressImage:image newWidth:image.size.width*compression], compression);
    }
    return compressedData;
}

+ (UIImage *)compressImage:(UIImage *)image newWidth:(CGFloat)newImageWidth{
    if (!image) return nil;
    float imageWidth = image.size.width;
    float imageHeight = image.size.height;
    float width = newImageWidth;
    float height = image.size.height/(image.size.width/width);
    
    float widthScale = imageWidth /width;
    float heightScale = imageHeight /height;
    
    UIGraphicsBeginImageContext(CGSizeMake(width, height));
    if (widthScale > heightScale) {
        [image drawInRect:CGRectMake(0, 0, imageWidth /heightScale , height)];
    } else {
        [image drawInRect:CGRectMake(0, 0, width , imageHeight /widthScale)];
    }
    
    UIImage *newImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return newImage;
}

@end

#pragma mark - 批量请求
#pragma mark -

static NSMutableArray <TTNetworkServer *>*_tempArray;
static NSMutableArray *_successArray;
static NSMutableArray *_failureArray;
static NSMutableArray *_sessionTaskArray;

@implementation TTNetworkServer (TTNetworkBatch)

- (NSString *)urlString {
    return objc_getAssociatedObject(self, _cmd);
}
- (void)setUrlString:(NSString *)url {
    objc_setAssociatedObject(self, @selector(urlString), url, OBJC_ASSOCIATION_COPY_NONATOMIC);
}

- (NSDictionary *)requestParameters{
    return objc_getAssociatedObject(self, _cmd);
}
- (void)setRequestParameters:(NSDictionary *)para {
    objc_setAssociatedObject(self, @selector(requestParameters), para, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (NSString *)httpMethod {
    return objc_getAssociatedObject(self, _cmd);
}
- (void)setHttpMethod:(NSString *)method {
    objc_setAssociatedObject(self, @selector(httpMethod), method, OBJC_ASSOCIATION_COPY_NONATOMIC);
}

- (id)cacheResponse {
    return objc_getAssociatedObject(self, _cmd);
}
- (void)setCacheResponse:(TTRequestCache)cache {
    objc_setAssociatedObject(self, @selector(cacheResponse), cache, OBJC_ASSOCIATION_COPY_NONATOMIC);
}

+ (TTNetworkServer *)addGET:(NSString *)url parameters:(NSDictionary *)parameters cacheResponse:(TTRequestCache)cacheResponse {
    return [self serverWithURL:url parameters:parameters cacheResponse:cacheResponse method:@"GET"];
}
+ (TTNetworkServer *)addPOST:(NSString *)url parameters:(NSDictionary *)parameters cacheResponse:(TTRequestCache)cacheResponse {
    return [self serverWithURL:url parameters:parameters cacheResponse:cacheResponse method:@"POST"];
}

+ (NSMutableArray <TTNetworkServer *>*)tempArray {
    if (_tempArray == nil) {
        _tempArray = @[].mutableCopy;
    }
    return _tempArray;
}

+ (NSMutableArray *)successArray {
    if (_successArray == nil) {
        _successArray = @[].mutableCopy;
    }
    return _successArray;
}

+ (NSMutableArray *)failureArray {
    if (_failureArray == nil) {
        _failureArray = @[].mutableCopy;
    }
    return _failureArray;
}

+ (NSMutableArray *)sessionTaskArray {
    if (_sessionTaskArray == nil) {
        _sessionTaskArray = @[].mutableCopy;
    }
    return _sessionTaskArray;
}

+ (TTNetworkServer *)serverWithURL:(NSString *)url parameters:(NSDictionary *)para cacheResponse:(TTRequestCache)cache method:(NSString *)method {
    pthread_mutex_lock(&_mutexLock);
    TTNetworkServer *server = [[TTNetworkServer alloc] init];
    server.urlString = url;
    server.requestParameters = para;
    server.httpMethod = method;
    server.cacheResponse = cache;
    [[TTNetworkServer tempArray] addObject:server];
    pthread_mutex_unlock(&_mutexLock);
    return server;
}

+ (void)startBatchRequest:(NSArray<TTNetworkServer *> *)request
                  success:(void(^)(NSArray<id> *))success
                  failure:(void(^)(NSArray<id> *))failure
                     task:(void(^)(NSArray<NSURLSessionDataTask *> *))task{
#if DEBUG
    NSAssert(request.count > 1 , @"至少含有2个以上请求");
#else
    if (request.count <= 1) {return;}
#endif
    static BOOL onRequest = NO;
    if (onRequest) {
        return;
    }
    dispatch_group_t group = dispatch_group_create();
    for (int i = 0; i < request.count; i++) {
        onRequest = YES;
        TTNetworkServer *server = request[i];
        TTLog(@"===%@==%@===%@",server.urlString,server.requestParameters,server.httpMethod);
        NSNull *null = [NSNull null];
        NSURLSessionDataTask *task = [NSURLSessionDataTask new];
        [[self successArray] addObject:null];
        [[self failureArray] addObject:null];
        [[self sessionTaskArray] addObject:task];
        dispatch_group_async(group, dispatch_get_global_queue(0, 0), ^{
            [self startRequest:server group:group];
        });
    }
    dispatch_group_notify(group, dispatch_get_main_queue(), ^{
        success ? success([self successArray]) : nil;
        failure ? failure([self failureArray]) : nil;
        task ? task([self sessionTaskArray]) : nil;
        [[self successArray] removeAllObjects];
        [[self failureArray] removeAllObjects];
        [[self sessionTaskArray] removeAllObjects];
        onRequest = NO;
    });
}

+ (void)startRequest:(TTNetworkServer *)server group:(dispatch_group_t)group{
    dispatch_group_enter(group);
    if ([server.httpMethod isEqualToString:@"GET"]) {
        [TTNetworkServer GET:server.urlString parameters:server.requestParameters cacheResponse:server.cacheResponse succeess:^(NSURLSessionDataTask *task, NSDictionary * responseObject) {
            [self handlerResultWithTask:task response:responseObject ? : [NSNull null] error:[NSNull null] group:group];
        } failure:^(NSURLSessionDataTask *task, NSError *error) {
            [self handlerResultWithTask:task response:[NSNull null] error:error group:group];
        }];
    } else if ([server.httpMethod isEqualToString:@"POST"]) {
        [TTNetworkServer POST:server.urlString parameters:server.requestParameters cacheResponse:server.cacheResponse success:^(NSURLSessionDataTask *task, NSDictionary * responseObject) {
            [self handlerResultWithTask:task response:responseObject ? : [NSNull null] error:[NSNull null] group:group];
        } failure:^(NSURLSessionDataTask *task, NSError *error) {
            [self handlerResultWithTask:task response:[NSObject new] error:error group:group];
        }];
    }
}

+ (void)handlerResultWithTask:(NSURLSessionDataTask *)task response:(id)response error:(id)error group:(dispatch_group_t)group{
    [[self tempArray] enumerateObjectsUsingBlock:^(TTNetworkServer * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if ([task.currentRequest.URL.absoluteString containsString:obj.urlString]) {
            [[self successArray] replaceObjectAtIndex:idx withObject:response];
            [[self failureArray] replaceObjectAtIndex:idx withObject:error];
            [[self sessionTaskArray] replaceObjectAtIndex:idx withObject:task];
            *stop = YES;
        }
    }];
    dispatch_group_leave(group);
}

@end

#pragma mark - 网络缓存
#pragma mark -

@implementation TTNetworkServer (TTNetworkCache)

///获取所有缓存的大小 单位：bytes
+ (NSUInteger)allCacheSize {
    return [[_TTNetworkCache standardCache].diskCache totalCost];
}
///清除所有缓存
+ (void)clearCache {
    [[_TTNetworkCache standardCache] removeAllObjects];
}

+ (void)clearCacheWithProgress:(void(^)(int removedCount, int totalCount))progress
                    completion:(void(^)(BOOL error))handler {
    [[_TTNetworkCache standardCache] removeAllObjectsWithProgressBlock:progress endBlock:handler];
}

@end

#pragma mark - 退出控制器时取消网络请求
#pragma mark -


@implementation UIViewController (TTNetwork)

+ (void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Class class = [self class];
        
        SEL oriSel = @selector(viewDidDisappear:);
        SEL newSel = @selector(tt_viewDidDisappear:);
        
        Method oriMethod = class_getInstanceMethod(class, oriSel);
        Method newMethod = class_getInstanceMethod(class, newSel);
        
        BOOL success = class_addMethod(class, oriSel, method_getImplementation(newMethod), method_getTypeEncoding(newMethod));
        if (success) {
            class_replaceMethod(class, newSel, method_getImplementation(oriMethod), method_getTypeEncoding(oriMethod));
        } else {
            method_exchangeImplementations(oriMethod, newMethod);
        }
    });
}

- (void)tt_viewDidDisappear:(BOOL)animated{
    [self tt_viewDidDisappear:animated];
    if (self.cancelAllTasksWhileViewDidDisappear) {
        [self tt_logCancelTask];
        [TTNetworkServer cancelAllTask];
    }
}

- (BOOL)cancelAllTasksWhileViewDidDisappear {
    return [objc_getAssociatedObject(self, _cmd) boolValue];
}

- (void)setCancelAllTasksWhileViewDidDisappear:(BOOL)cancelAllTasksWhileViewDidDisappear {
    objc_setAssociatedObject(self, @selector(cancelAllTasksWhileViewDidDisappear), @(cancelAllTasksWhileViewDidDisappear), OBJC_ASSOCIATION_ASSIGN);
}

- (void)tt_logCancelTask {
    if (_allSessionTask.count > 0) {
        TTLog(@"已取消%@ 控制器未完成的请求",self);
        [_allSessionTask enumerateObjectsUsingBlock:^(NSURLSessionTask * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            NSString *url = obj.currentRequest.URL.absoluteString;
            TTLog(@"取消的请求：%@",url);
        }];
    }
}

@end


#pragma mark - 中文输出
#pragma mark -
#ifdef DEBUG
@implementation NSArray (LocaleLog)

- (NSString *)descriptionWithLocale:(id)locale {
    NSMutableString *mStr = [NSMutableString stringWithString:@"[\n"];
    [self enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        [mStr appendFormat:@"\t%@,\n", obj];
    }];
    [mStr appendString:@"]"];
    NSRange range = [mStr rangeOfString:@"," options:NSBackwardsSearch];
    if (range.location != NSNotFound){
        [mStr deleteCharactersInRange:range];
    }
    return mStr;
}

@end

@implementation NSDictionary (LocaleLog)

- (NSString *)descriptionWithLocale:(id)locale {
    NSMutableString *mStr = [NSMutableString stringWithString:@"{\n"];
    [self enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
        [mStr appendFormat:@"\t%@ = %@;\n", key, obj];
    }];
    [mStr appendString:@"}"];
    NSRange range = [mStr rangeOfString:@"," options:NSBackwardsSearch];
    if (range.location != NSNotFound){
        [mStr deleteCharactersInRange:range];
    }
    return mStr;
}
@end
#endif

