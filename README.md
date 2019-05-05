# TileOverlay
iOS在高德地图上自定义瓦片地图

## 瓦片地图
首先解释一下什么是瓦片地图，我们使用的地图(例如百度，高德)都有一个底图，在每一级的缩放比例下，都有一张很大的底图，这张底图按固定的大小切割成若干份，在地图显示时根据显示范围和缩放比例，请求对应几张小的底图，这些底图就是瓦片地图。

## 项目需求
项目使用的是[高德地图](https://lbs.amap.com/api/ios-sdk/summary/)，基本的操作可以参考官方文档，然后需要叠加自己的瓦片地图。在官方文档中找了好久，终于在[绘制面_绘制瓦片图层](https://lbs.amap.com/api/ios-sdk/guide/draw-on-map/draw-plane/?sug_index=0#overlay)这一节中找到了相应的方法。主要步骤是先添加一个`MATileOverlay `到地图中，然后实现delegate中的`mapView:viewForOverlay:`函数，返回一个renderer对象。项目中用到的所有地图都要加载这个瓦片服务，所以直接从`MAMapView`继承出一个自定义MapView。

## 代码实现
自定义一个`PPGMapView`，继承自`MAMapView`。
``` objc
#import <MAMapKit/MAMapKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface PPGMapView : MAMapView

@end

NS_ASSUME_NONNULL_END
```
在初始化时添加自定义瓦片图层。
```objc
- (void)commonInit {
    // delegate指向自己
    self.delegate = self;
    // 初始化缩放级别
    self.zoomLevel = 18.f;
    self.showsUserLocation = YES;
    self.userTrackingMode = MAUserTrackingModeFollow;
    // 添加自定义瓦片图层
    PPGTileOverlay *overlay = [[PPGTileOverlay alloc] init];
    overlay.maximumZ = 20;
    overlay.minimumZ = 14;
    overlay.boundingMapRect = MAMapRectWorld;
    [self addOverlay:overlay];
}
```

实现`renderer`方法
```objc
- (MAOverlayRenderer *)mapView:(MAMapView *)mapView rendererForOverlay:(id <MAOverlay>)overlay {
    // 外部delegate首先进行响应，如果没有实现，则使用自定义地图的实现
    if ([self.extDelegate respondsToSelector:_cmd]) {
        MAOverlayRenderer *renderer = [self.extDelegate mapView:mapView rendererForOverlay:overlay];
        if (renderer) {
            return renderer;
        }
    }
    if ([overlay isKindOfClass:[MATileOverlay class]]) {
        // 默认的瓦片底图renderer
        MATileOverlayRenderer *renderer = [[MATileOverlayRenderer alloc] initWithTileOverlay:overlay];
        return renderer;
    }
    return nil;
}
```

下面是自定义瓦片地图的代码
```objc
/**
 自定义瓦片图层，继承自MATileOverlay
 */
@interface PPGTileOverlay : MATileOverlay

@end

@implementation PPGTileOverlay

- (NSURL *)URLForTilePath:(MATileOverlayPath)path {
#warning 自行替换ip和端口号
    NSString *urlStr = [NSString stringWithFormat:@"http://ip:port/mapImg/tiles/%ld/%ld_%ld.png", (long)path.z, (long)path.x, (long)path.y];
    return [NSURL URLWithString:urlStr];
}

// 使用template和上面的方法会丢掉端口号，所以自己去请求，然后回调结果
- (void)loadTileAtPath:(MATileOverlayPath)path result:(void (^)(NSData *, NSError *))result {
    NSURL *url = [self URLForTilePath:path];
    // 使用SDWebImage管理本地瓦片
    SDImageCache *cache = [SDImageCache sharedImageCache];
    UIImage *image = [cache imageFromCacheForKey:[url absoluteString]];
    if (image) {
        result(UIImagePNGRepresentation(image), nil);
    } else {
        // 在3D地图中如果瓦片请求失败，会一直重复去请求，这里用set存储已请求的瓦片，不做重复请求
        static NSMutableSet *urlSet;
        if (urlSet == nil) {
            urlSet = [NSMutableSet new];
        }
        if ([urlSet containsObject:url]) {
            return;
        }
        [[SDWebImageDownloader sharedDownloader] downloadImageWithURL:url options:SDWebImageDownloaderHighPriority progress:nil completed:^(UIImage * _Nullable image, NSData * _Nullable data, NSError * _Nullable error, BOOL finished) {
            if (finished && data) {
                [cache storeImageDataToDisk:data forKey:[url absoluteString]];
            }
            result(data, error);
            [urlSet addObject:url];
        }];
    }
}

@end
```

到这里瓦片地图就添加上去了，这里还有一个delegate的问题，因为我们初始化的时候设置delegate为自己了，瓦片地图才能正常显示，如果这是在使用的时候delegate设置为另外一个对象，而他没实现上面的renderer 方法，那么我们的瓦片地图又不能显示了，所以这里使用了外部delegate方法。

在自定义MapView中添加一个Extension，添加私有属性extDelegate
```objc
@interface PPGMapView () <MAMapViewDelegate>

/**
 外部的代理
 */
@property (nonatomic, weak) id<MAMapViewDelegate> extDelegate;

@end
```

重写setDelegate方法和respondsToSelector方法
```objc
// 保存本地delegate，记录外部delegate
- (void)setDelegate:(id<MAMapViewDelegate>)delegate {
    if (delegate == self) {
        [super setDelegate:delegate];
    } else {
        self.extDelegate = delegate;
    }
}

- (BOOL)respondsToSelector:(SEL)aSelector {
    BOOL responds = [super respondsToSelector:aSelector];
    if (responds) {
        return responds;
    } else {
        return [self.extDelegate respondsToSelector:aSelector];
    }
}
```

runtime转发方法到外部delegate
```objc
// runtime消息转发
- (id)forwardingTargetForSelector:(SEL)aSelector {
    if ([self.extDelegate respondsToSelector:aSelector]) {
        return self.extDelegate;
    }
    return nil;
}
```
