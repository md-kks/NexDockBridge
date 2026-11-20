#import <Cocoa/Cocoa.h>
#import <IOKit/hid/IOHIDLib.h>
#import <ApplicationServices/ApplicationServices.h>
#import <math.h>
static IOHIDManagerRef manager;
static NSStatusItem *status;
static NSMenuItem *info;
static BOOL enabled=YES, leftDown=NO, rightDown=NO;
static BOOL gesture=NO, physical=NO, hadMulti=NO, hadExtra=NO;
static int prevCount=0, prevID=-1, clickCount[2]={0,0};
static double previousClick[2]={0,0};
static CGPoint previousClickPos[2];
typedef struct {int id,x,y; BOOL tip;} Contact;
static Contact frame[16];
static int expected=0, received=0, scan=-1;
static double prevX,prevY,gestureStart,travel,scrollTravel,scrollRemainderX,scrollRemainderY;
static unsigned long taps,scrolls;
static double remX,remY;
static unsigned long reports,moves,clicks;
static double speed=0.65;
static CGPoint cursor(void) {
 CGEventRef e=CGEventCreate(NULL); CGPoint p=e?CGEventGetLocation(e):CGPointZero; if(e)CFRelease(e); return p;
}
static void postButton(BOOL right,BOOL down) {
 CGPoint p=cursor(); CGEventRef e=CGEventCreateMouseEvent(NULL,right?(down?kCGEventRightMouseDown:kCGEventRightMouseUp):(down?kCGEventLeftMouseDown:kCGEventLeftMouseUp),p,right?kCGMouseButtonRight:kCGMouseButtonLeft);
 if(e){
 int idx=right?1:0;
 if(down){
  double now=CFAbsoluteTimeGetCurrent();
  if(now-previousClick[idx]<[NSEvent doubleClickInterval] && hypot(p.x-previousClickPos[idx].x,p.y-previousClickPos[idx].y)<7)
    clickCount[idx]=(clickCount[idx]%3)+1;
  else clickCount[idx]=1;
  previousClick[idx]=now;previousClickPos[idx]=p;
 }
 CGEventSetIntegerValueField(e,kCGMouseEventClickState,clickCount[idx]);
 CGEventPost(kCGHIDEventTap,e);CFRelease(e);if(down)clicks++;
 }
}
static void resetState(void) {
 if(leftDown)postButton(NO,NO);if(rightDown)postButton(YES,NO);
 leftDown=rightDown=gesture=physical=hadMulti=hadExtra=NO;prevCount=0;prevID=-1;remX=remY=0;expected=received=0;scan=-1;scrollRemainderX=scrollRemainderY=0;
}
static void movePointer(double dx,double dy) {
 CGPoint p=cursor(); p.x+=dx;p.y+=dy;
 // Clip to the connected display nearest to the current pointer.
 CGDirectDisplayID displays[16]; uint32_t count=0;
 if(CGGetDisplaysWithPoint(cursor(),16,displays,&count)==kCGErrorSuccess && count){
 CGRect b=CGDisplayBounds(displays[0]);p.x=fmax(CGRectGetMinX(b),fmin(CGRectGetMaxX(b)-1,p.x));p.y=fmax(CGRectGetMinY(b),fmin(CGRectGetMaxY(b)-1,p.y));
 }
 CGEventType type=leftDown?kCGEventLeftMouseDragged:rightDown?kCGEventRightMouseDragged:kCGEventMouseMoved;
 CGEventRef e=CGEventCreateMouseEvent(NULL,type,p,rightDown?kCGMouseButtonRight:kCGMouseButtonLeft);
 if(e){CGEventSetIntegerValueField(e,kCGMouseEventDeltaX,(int64_t)dx);CGEventSetIntegerValueField(e,kCGMouseEventDeltaY,(int64_t)dy);CGEventPost(kCGHIDEventTap,e);CFRelease(e);moves++;}
}
static void tap(BOOL right){
 postButton(right,YES);postButton(right,NO);taps++;
}
static void scrollPointer(double dx,double dy) {
 scrollRemainderX+=dx*0.55;scrollRemainderY+=dy*0.55;
 int x=(int)scrollRemainderX,y=(int)scrollRemainderY;
 scrollRemainderX-=x;scrollRemainderY-=y;
 if(!x&&!y)return;
 CGEventRef ev=CGEventCreateScrollWheelEvent(NULL,kCGScrollEventUnitPixel,2,y,x);
 if(ev){CGEventSetIntegerValueField(ev,kCGScrollWheelEventIsContinuous,1);CGEventPost(kCGHIDEventTap,ev);CFRelease(ev);scrolls++;}
}
static void processFrame(void) {
 int count=0,first=-1; double x=0,y=0;
 for(int i=0;i<received;i++)if(frame[i].tip){if(first<0)first=i;count++;x+=frame[i].x;y+=frame[i].y;}
 if(count){x/=count;y/=count;}
 double now=CFAbsoluteTimeGetCurrent();
 if(!count){
  if(gesture&&!physical&&!leftDown&&!rightDown&&!hadExtra){
   if(!hadMulti&&travel<30&&now-gestureStart<0.26)tap(NO);
   else if(hadMulti&&travel<35&&scrollTravel<35&&now-gestureStart<0.38)tap(YES);
  }
  gesture=physical=hadMulti=hadExtra=NO;prevCount=0;prevID=-1;remX=remY=0;scrollRemainderX=scrollRemainderY=0;
  return;
 }
 if(!gesture){
  gesture=YES;gestureStart=now;physical=leftDown||rightDown;hadMulti=hadExtra=NO;travel=scrollTravel=0;prevCount=0;prevID=-1;
 }
 if(count>=2)hadMulti=YES;
 if(count>2)hadExtra=YES;
 if(count==2&&!hadExtra){
  if(prevCount==2){
   double dx=x-prevX,dy=y-prevY;
   if(fabs(dx)<400&&fabs(dy)<400){
    double dist=hypot(dx,dy);scrollTravel+=dist;
    if(scrollTravel>16)scrollPointer(dx,dy);
   }
  }
 }else if(count==1&&!hadMulti){
  if(prevCount==1&&prevID==frame[first].id){
   double dx=x-prevX,dy=y-prevY;
   if(fabs(dx)<500&&fabs(dy)<500){
    double magnitude=hypot(dx,dy);travel+=magnitude;
    double gain=speed*(1.0+fmin(magnitude/100.0,0.7));
    remX+=dx*gain;remY+=dy*gain;
    int mx=(int)remX,my=(int)remY;remX-=mx;remY-=my;
    if(mx||my)movePointer(mx,my);
   }
  }
 }
 prevCount=count;prevID=count==1?frame[first].id:-1;prevX=x;prevY=y;
}
static void input(void *c,IOReturn result,void *sender,IOHIDReportType type,uint32_t id,uint8_t*b,CFIndex n) {
 if(result||id!=0x1e||n<8||b[0]!=0x1e)return;
 reports++;
 if(!enabled||!CGPreflightPostEventAccess())return;
 int count=b[7]&15, time=b[5]|(b[6]<<8);
 // Nonzero count marks the first report of a scan. Following contacts carry zero.
 if(count>0){
  if(received>0&&received<expected){expected=received=0;}
  expected=count;received=0;scan=time;
  // The hardware emits 0x20 for left and 0x40 for right.
  BOOL left=(b[7]&0x20)!=0,right=(b[7]&0x40)!=0;
  if(left||right||leftDown||rightDown)physical=YES;
  if(left!=leftDown){postButton(NO,left);leftDown=left;}
  if(right!=rightDown){postButton(YES,right);rightDown=right;}
 }else if(expected<=0||time!=scan)return;
 if(received>=16)return;
 frame[received++]=(Contact){b[1]>>4,b[2]|((b[3]&15)<<8),(b[3]>>4)|(b[4]<<4),(b[1]&3)==3};
 if(received>=expected){processFrame();expected=received=0;}
}
static void removed(void*c,IOReturn r,void*s,IOHIDDeviceRef d){resetState();}
@interface Delegate:NSObject<NSApplicationDelegate>
@end
@implementation Delegate
-(void)applicationDidFinishLaunching:(NSNotification*)n {
 [NSApp setActivationPolicy:NSApplicationActivationPolicyAccessory];
 status=[[NSStatusBar systemStatusBar]statusItemWithLength:NSVariableStatusItemLength];
 status.button.title=@"NexDock";
 NSMenu*m=[NSMenu new];info=[[NSMenuItem alloc]initWithTitle:@"Starting…" action:nil keyEquivalent:@""];[m addItem:info];
 [m addItemWithTitle:@"Allow mouse control…" action:@selector(permission:) keyEquivalent:@""].target=self;
 [m addItemWithTitle:@"Pause / Resume" action:@selector(toggle:) keyEquivalent:@""].target=self;
 [m addItemWithTitle:@"Slower" action:@selector(slower:) keyEquivalent:@""].target=self;
 [m addItemWithTitle:@"Faster" action:@selector(faster:) keyEquivalent:@""].target=self;
 [m addItem:[NSMenuItem separatorItem]];
 [m addItemWithTitle:@"Quit NexDockBridge" action:@selector(quit:) keyEquivalent:@"q"].target=self;
 status.menu=m;
 manager=IOHIDManagerCreate(kCFAllocatorDefault,0);
 NSDictionary*match=@{@kIOHIDVendorIDKey:@(0x258a),@kIOHIDProductIDKey:@(0xf08),@kIOHIDPrimaryUsagePageKey:@1,@kIOHIDPrimaryUsageKey:@2};
 IOHIDManagerSetDeviceMatching(manager,(__bridge CFDictionaryRef)match);
 IOHIDManagerRegisterInputReportCallback(manager,input,NULL);
 IOHIDManagerRegisterDeviceRemovalCallback(manager,removed,NULL);
 IOHIDManagerScheduleWithRunLoop(manager,CFRunLoopGetMain(),kCFRunLoopCommonModes);
 IOReturn r=IOHIDManagerOpen(manager,kIOHIDOptionsTypeNone);
 NSLog(@"HID manager open: %08x",r);
 [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(tick:) userInfo:nil repeats:YES];
 if(!CGPreflightPostEventAccess())[self permission:nil];
}
-(void)permission:(id)s {
 if(!CGPreflightPostEventAccess()){CGRequestPostEventAccess();NSDictionary* opts=@{(__bridge NSString*)kAXTrustedCheckOptionPrompt:@YES};AXIsProcessTrustedWithOptions((__bridge CFDictionaryRef)opts);}
}
-(void)tick:(id)s {
 CFSetRef ds=IOHIDManagerCopyDevices(manager);long count=ds?CFSetGetCount(ds):0;if(ds)CFRelease(ds);
 BOOL allowed=CGPreflightPostEventAccess();
 info.title=[NSString stringWithFormat:@"%@ | %ld device | %lu reports | %lu moves | %lu clicks | %lu taps | %lu scrolls",!enabled?@"Paused":!allowed?@"Permission required":@"Active",count,reports,moves,clicks,taps,scrolls];
 status.button.title=!enabled?@"NexDock ⏸":!allowed?@"NexDock !":@"NexDock";
 static unsigned long prev=0;
 if(prev!=reports){NSLog(@"reports=%lu moves=%lu clicks=%lu taps=%lu scrolls=%lu permission=%d",reports,moves,clicks,taps,scrolls,allowed);prev=reports;}
}
-(void)toggle:(id)s {enabled=!enabled;resetState();}
-(void)slower:(id)s {speed=fmax(.15,speed-.1);}
-(void)faster:(id)s {speed=fmin(2.5,speed+.1);}
-(void)quit:(id)s {resetState();[NSApp terminate:nil];}
@end
int main(int argc,const char**argv){@autoreleasepool{NSApplication*app=[NSApplication sharedApplication];Delegate*d=[Delegate new];app.delegate=d;[app run];}return 0;}
