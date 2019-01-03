//
//  ViewController.m
//  OpenGL-ES-003-GLSL绘制3D纹理
//
//  Created by zhongding on 2019/1/2.
//

#import "ZFViewController.h"
#import "ZFView.h"
@interface ZFViewController ()

@property(nonatomic,strong)ZFView *cView;


@end

@implementation ZFViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.cView = (ZFView *)self.view;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    
}


@end
