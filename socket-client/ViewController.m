//
//  ViewController.m
//  socket-client
//
//  Created by 张天龙 on 2022/5/14.
//

#import "ViewController.h"
#import "GCDAsyncSocket.h"

#define VA_COMADN_ID 0x00000001
#define VA_COMADN_HEARTBEAT_ID 0x00000002
#define server_host @"127.0.0.1"
#define server_port 6969

#define dispatch_main_async_safe(block)\
    if ([NSThread isMainThread]) {\
        block();\
    } else {\
        dispatch_async(dispatch_get_main_queue(), block);\
    }


@interface ViewController ()<GCDAsyncSocketDelegate>
@property (nonatomic,strong) GCDAsyncSocket *clientSocket;
@property (nonatomic,assign) NSTimeInterval reConnectTime;
@property (nonatomic,strong) NSTimer *heartBeat;
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


//初始化心跳
- (void)initHeartBeat
{
 
    dispatch_main_async_safe(^{
 
        [self destoryHeartBeat];
 
        __weak typeof(self) weakSelf = self;
        //心跳设置为3分钟，NAT超时一般为5分钟
        self.heartBeat = [NSTimer scheduledTimerWithTimeInterval:3*60 repeats:YES block:^(NSTimer * _Nonnull timer) {
            NSLog(@"send heart Beat");
            //和服务端约定好发送什么作为心跳标识，尽可能的减小心跳包大小
            [weakSelf sendHeartBeat];
        }];
        [[NSRunLoop currentRunLoop]addTimer:self.heartBeat forMode:NSRunLoopCommonModes];
    })
 
}

//取消心跳
- (void)destoryHeartBeat
{
    dispatch_main_async_safe(^{
        if (self.heartBeat) {
            [self.heartBeat invalidate];
            self.heartBeat = nil;
        }
    })
 
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

- (void)reConnect{
    
    //超过一分钟就不再重连 所以只会重连5次 2^5 = 64
    if (_reConnectTime >16) {
        NSLog(@"重连次数超过5次，不再重连");
        _reConnectTime = 0;
        return;
    }
    
    NSTimeInterval aReConnectTime = self.reConnectTime;
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(aReConnectTime * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        NSLog(@"开始重连..._reConnectTime = %f",aReConnectTime);
            [self connect];
        });
     
        //重连时间2的指数级增长
        if (_reConnectTime == 0) {
            _reConnectTime = 2;
        }else{
            _reConnectTime *= 2;
        }
    
}

#pragma mark - GCDAsyncSocketDelegate

- (void)socket:(GCDAsyncSocket *)sock didConnectToHost:(NSString *)host port:(uint16_t)port{
    NSLog(@"连接成功");
    //每次正常连接的时候清零重连时间
    _reConnectTime = 0;
//    连接成功了开始发送心跳
    [self initHeartBeat];
    [_clientSocket readDataWithTimeout:-1 tag:0];
}

- (void)socket:(GCDAsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag{
    NSLog(@"接收到消息");
    [_clientSocket readDataWithTimeout:-1 tag:0];
}

- (void)socketDidDisconnect:(GCDAsyncSocket *)sock withError:(NSError *)err{
    NSLog(@"断开连接,errorCode = %ld,err.localizedDescription = %@",err.code,err.localizedDescription);
    //errorCode:0表示自己断开的，7表示服务端断开，61表示服务端未开启，被拒绝了
    //32是Broken pipe，APP到后台的时候
    if (err.code != 0) {
        [self reConnect];
    }
    //断开连接时销毁心跳
    [self destoryHeartBeat];
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

- (void)sendHeartBeat{

    NSMutableData *totalData = [NSMutableData data];
    
    //拼接前4个字节
    unsigned int totalSize = 4 + 4;
    NSData *totalSizeData = [NSData dataWithBytes:&totalSize length:4];
    [totalData appendData:totalSizeData];
    
    //拼接指令
    unsigned int commanID = VA_COMADN_HEARTBEAT_ID;
    NSData *commanIDData = [NSData dataWithBytes:&commanID length:4];
    [totalData appendData:commanIDData];
    
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
