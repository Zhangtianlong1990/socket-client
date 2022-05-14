//
//  ViewController.m
//  socket-client
//
//  Created by 张天龙 on 2022/5/14.
//

#import "ViewController.h"
#import "GCDAsyncSocket.h"

#define VA_COMADN_ID 0x00000001
#define server_host @"127.0.0.1"
#define server_port 6969

@interface ViewController ()<GCDAsyncSocketDelegate>
@property (nonatomic,strong) GCDAsyncSocket *clientSocket;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self initUI];
    
    [self initGCDAsyncSocket];
    
}

- (void)initGCDAsyncSocket{
    //创建socket
    if (_clientSocket == nil) {
        _clientSocket = [[GCDAsyncSocket alloc] initWithDelegate:self delegateQueue:dispatch_get_main_queue()];
    }
}

- (BOOL)connect{
    NSError *error = nil;
    BOOL connectFlag = [_clientSocket connectToHost:server_host onPort:server_port error:&error];
    if (error) {
        NSLog(@"%@",error);
    }
    return  connectFlag;
}

- (void)disConnect{
    [_clientSocket disconnect];
}

#pragma mark - GCDAsyncSocketDelegate

- (void)socket:(GCDAsyncSocket *)sock didConnectToHost:(NSString *)host port:(uint16_t)port{
    NSLog(@"连接成功");
    [_clientSocket readDataWithTimeout:-1 tag:0];
}

- (void)socket:(GCDAsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag{
    NSLog(@"接收到消息");
    [_clientSocket readDataWithTimeout:-1 tag:0];
}

- (void)socketDidDisconnect:(GCDAsyncSocket *)sock withError:(NSError *)err{
    NSLog(@"断开连接%@",err.localizedDescription);
}

#pragma mark - input

- (void)didClickConnectButton{
    [self connect];
}

- (void)didClickSendButton{
    [self sendImage];
}

- (void)didClickDisconnectButton{
    [self disConnect];
}

#pragma mark - private

- (CGFloat)screenWidth{
    return [UIScreen mainScreen].bounds.size.width;
}

- (UIButton *)creatButtonWithTitle:(NSString *)title action:(SEL)action{
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    [button setTitle:title forState:UIControlStateNormal];
    [button setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    button.backgroundColor = [UIColor blueColor];
    [button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    return button;
}

- (void)sendImage{
    //图片数据
    UIImage *img = [UIImage imageNamed:@"icon_tree"];
    NSData *imageData = UIImagePNGRepresentation(img);
    
    NSMutableData *totalData = [NSMutableData data];
    
    //拼接前4个字节
    unsigned int totalSize = 4 + 4 + (int)imageData.length;
    NSData *totalSizeData = [NSData dataWithBytes:&totalSize length:4];
    [totalData appendData:totalSizeData];
    
    //拼接指令
    unsigned int commanID = VA_COMADN_ID;
    NSData *commanIDData = [NSData dataWithBytes:&commanID length:4];
    [totalData appendData:commanIDData];
    
    //拼接图片数据
    [totalData appendData:imageData];
    
    [_clientSocket writeData:totalData withTimeout:-1 tag:0];
    
}

#pragma mark - UI

- (void)initUI{
    CGFloat buttonWidth = 100;
    CGFloat buttonHeight = 50;
    CGFloat connectY = 100;
    CGFloat connectX = ([self screenWidth] - buttonWidth)*0.5;
    CGRect connectF = CGRectMake(connectX, connectY, buttonWidth, buttonHeight);
    UIButton *connectButton = [self creatButtonWithTitle:@"连接" action:@selector(didClickConnectButton)];
    connectButton.frame = connectF;
    [self.view addSubview:connectButton];
    
    CGFloat sendY = CGRectGetMaxY(connectF) + 50;
    CGFloat sendX = connectX;
    CGRect sendF = CGRectMake(sendX, sendY, buttonWidth, buttonHeight);
    UIButton *sendButton = [self creatButtonWithTitle:@"发送" action:@selector(didClickSendButton)];
    sendButton.frame = sendF;
    [self.view addSubview:sendButton];
    
    CGFloat disconnectY = CGRectGetMaxY(sendF) + 50;
    CGFloat disconnectX = connectX;
    CGRect disconnectF = CGRectMake(disconnectX, disconnectY, buttonWidth, buttonHeight);
    UIButton *disconnectButton = [self creatButtonWithTitle:@"断开" action:@selector(didClickDisconnectButton)];
    disconnectButton.frame = disconnectF;
    [self.view addSubview:disconnectButton];
    
}

@end