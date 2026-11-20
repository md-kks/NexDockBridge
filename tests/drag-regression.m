#import <Cocoa/Cocoa.h>
#import <ApplicationServices/ApplicationServices.h>
#include <assert.h>
static unsigned dragEvents,scrollEvents,moveEvents;
static void fakePost(CGEventTapLocation loc, CGEventRef event) {
 (void)loc;
 switch(CGEventGetType(event)){
 case kCGEventLeftMouseDragged: case kCGEventRightMouseDragged: dragEvents++;break;
 case kCGEventScrollWheel: scrollEvents++;break;
 case kCGEventMouseMoved: moveEvents++;break;
 default:break;
 }
}
#define CGEventPost fakePost
#define main bridge_app_main
#include "../src/bridge.m"
#undef main
#undef CGEventPost
static void sample(Contact a,Contact b,int n){
 frame[0]=a;frame[1]=b;received=n;processFrame();
}
int main(void){@autoreleasepool{
 Contact thumb={0,140,800,YES},finger={1,600,300,YES},none={0,0,0,NO};
 resetState();
 sample(finger,none,1);
 finger.y+=20;sample(finger,none,1);assert(moveEvents==1);
 leftDown=YES;sample(thumb,finger,2);
 unsigned before=dragEvents;
 for(int i=0;i<5;i++){finger.y+=25;sample(thumb,finger,2);}
 assert(dragEvents-before==5);assert(scrollEvents==0);
 finger.y+=25;sample(finger,none,1);assert(dragEvents-before==6);
 leftDown=NO;sample(none,none,1);assert(taps==0);
 resetState();thumb.y=500;finger.y=300;sample(thumb,finger,2);
 for(int i=0;i<5;i++){thumb.y+=25;finger.y+=25;sample(thumb,finger,2);}
 assert(scrollEvents>0);assert(dragEvents-before==6);
 puts("PASS: regular movement, left-held two-contact drag, contact transition, no accidental scroll/tap, regular scroll");
 return 0;
}}
