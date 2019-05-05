//
//  ViewController.m
//  TileOverlay
//
//  Created by gaopeng on 2019/5/5.
//  Copyright © 2019 gaopeng. All rights reserved.
//

#import "ViewController.h"
#import "PPGMapView.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    PPGMapView *mapView = [[PPGMapView alloc] initWithFrame:self.view.bounds];
    [self.view addSubview:mapView];
    // 设置外部delegate也不影响瓦片地图显示
//    mapView.delegate = self;
}


@end
