# TTNetworkServer
对AFN的常用方法封装，支持缓存、批量请求、Cookie设置、返回数据自动转换为JSON（包括XML）、图片压缩上传等...

#基本用法
依赖的三方框架有AFNetworking、YYCache、MBProgressHUD，使用时请保证项目中含有这三个框架~
使用时`#import "TTNetworkServer.h"`

###基本设置
```ruby
TTNetworkConfig *config = [TTNetworkConfig standardConfig];
config.debugLogEnabled = YES;
config.baseURL = @"http://apicloud.mob.com";
```

如果需要为所有的请求添加公共参数，比如时间戳、版本号什么的，使用：  
```ruby
config.commonParameters = @{@"key1":@"value1"};
```  
如果需要在离开当前页面时取消当前页面上的所有请求，使用：  
```ruby
config.cancelAllTasksWhileViewDidDisAppear = YES;
```  

###Cookie的使用
如果需要使用cookie，先设置```ruby
config.cookieEnabled = YES;```,  
然后再获取cookie的请求里面调用```ruby
[TTNetworkServer getCookie:<#(NSURLSessionDataTask *)#>]```,  
退出时清除cookie```ruby
[TTNetworkServer clearCookie]```  
如果需要设置本地Cookie,请调用```ruby
[TTNetworkServer setLocalCookieWithCookieName:(NSArray *)names values:(NSArray *)values originURL:(NSString *)url expires:(NSTimeInterval)expires]```  

#网络请求

###基本请求
```ruby
[TTNetworkServer GET:(NSString *)url
parameters:(NSDictionary *)parameters
succeess:(TTRequestSuccessBlock)success
failure:(TTRequestFailureBlock)failure;]
```

###带缓存的请求
```ruby
[TTNetworkServer POST:(NSString *)url
parameters:(NSDictionary *)parameters
cacheResponse:(TTRequestCache)cacheResponse
success:(TTRequestSuccessBlock)success
failure:(TTRequestFailureBlock)failure]
```

###批量请求
```ruby
static NSString *const ConvertJSONFail = @"https://www.baidu.com";           
static NSString *const JSON = @"https://alpha-api.app.net/stream/0/posts/stream/global";        
static NSString *const JointURL = @"car/brand/query";       
static NSString *const XML = @"http://ws.webxml.com.cn/WebServices/WeatherWS.asmx/getRegionDataset";         
TTNetworkServer *server1 = [TTNetworkServer addGET:ConvertJSONFail parameters:nil cacheResponse:nil];           
TTNetworkServer *server2 = [TTNetworkServer addGET:JSON parameters:nil cacheResponse:nil];       
TTNetworkServer *server3 = [TTNetworkServer addGET:JointURL parameters:@{@"key":@"112fcd924b710"} cacheResponse:nil];             
TTNetworkServer *server4 = [TTNetworkServer addGET:XML parameters:nil cacheResponse:nil];      
[TTNetworkServer startBatchRequest:@[server1,server2,server3,server4] cacheResponse:nil     success:^(NSArray<id> *res) {    
//返回的数据顺序为加入请求的顺序     
id res0 = res[0];             
id res1 = res[1];             
id res2 = res[2];             
id res3 = res[3];            
} failure:^(NSArray<NSError *> *err) {             
} task:^(NSArray<NSURLSessionDataTask *> *task) {            
}];
end
```
###取消请求
1.取消某个URL的请求：```ruby
[TTNetworkServer cancelTaskWithURL:google]```    
2.取消所有请求：```ruby
[TTNetworkServer cancelAllTask]```      
3.退出VC时取消VC上的所有请求,请设置```ruby
[TTNetworkConfig standardConfig].cancelAllTasksWhileViewDidDisappear```   

###获取和清除缓存
```ruby
[TTNetworkServer allCacheSize]```    
```ruby
[TTNetworkServer clearCache]```      
```ruby
[TTNetworkServer clearCacheWithProgress:{} completion:{}]```   

###监听和获取网络状态
监听网络状态的变化     
```ruby
[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(networkStatusChange) name:TTNetworkStatusDidChangeNotification object:nil]
```
获取当前网络状态    
```ruby
[TTNetworkServer networkStatusType]```    

###如有BUG，请联系QQ/微信693388621~~



