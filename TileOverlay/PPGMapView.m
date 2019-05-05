//
//  PPGMapView.m
//  TileOverlay
//
//  Created by gaopeng on 2019/5/5.
//  Copyright © 2019 gaopeng. All rights reserved.
//

#import "PPGMapView.h"
#import <SDImageCache.h>
#import <SDWebImageDownloader.h>

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

@interface PPGMapView () <MAMapViewDelegate>

/**
 外部的代理
 */
@property (nonatomic, weak) id<MAMapViewDelegate> extDelegate;

@end

@implementation PPGMapView

- (instancetype)initWithCoder:(NSCoder *)coder {
    self = [super initWithCoder:coder];
    if (self) {
        [self commonInit];
    }
    return self;
}

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self commonInit];
    }
    return self;
}

/**
 初始化
 */
- (void)commonInit {
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

// runtime消息转发
- (id)forwardingTargetForSelector:(SEL)aSelector {
    if ([self.extDelegate respondsToSelector:aSelector]) {
        return self.extDelegate;
    }
    return nil;
}

@end
