//
//  JoystickViewController.m
//  Joystick
//
//  Copyright Matt Rajca 2010. All rights reserved.
//

#import "JoystickViewController.h"

#import "Packet.h"

@interface JoystickViewController ()

- (void)showBrowser;
- (void)processMotion:(CMDeviceMotion *)motion;

@end


@implementation JoystickViewController

@synthesize statusLabel;

// BGD http://www.flickr.com/photos/torley/2587091353/

#define FILTER 0.2f

- (id)initWithCoder:(NSCoder *)aDecoder {
	self = [super init];
	if (self) {
		_writeQueue = [[NSOperationQueue alloc] init];
		[_writeQueue setMaxConcurrentOperationCount:1];
		
		_motionManager = [[CMMotionManager alloc] init];
		_motionManager.deviceMotionUpdateInterval = 0.25f;
	}
	return self;
}

- (void)viewDidAppear:(BOOL)animated {
	[super viewDidAppear:animated];
	
	if (!_displayedOnce) {
		[self performSelector:@selector(showBrowser) withObject:nil afterDelay:0.25f];
		_displayedOnce = YES;
	}
}

- (void)showBrowser {
	BrowserViewController *vc = [[BrowserViewController alloc] init];
	vc.delegate = self;
	
	UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:vc];
	[vc release];
	
	vc.serviceType = @"_nxtjoystick._tcp.";
	vc.domain = @"";
	
	[self presentModalViewController:nav animated:YES];
	[nav release];	
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    return UIInterfaceOrientationIsLandscape(interfaceOrientation);
}

- (void)browserViewController:(BrowserViewController *)bvc didResolveService:(NSNetService *)service {
	[service getInputStream:NULL outputStream:&_outputStream];
	
	[_outputStream retain];
	[_outputStream setDelegate:self];
	[_outputStream scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSRunLoopCommonModes];
	[_outputStream open];
}

- (void)stream:(NSStream *)aStream handleEvent:(NSStreamEvent)eventCode {
	if (eventCode == NSStreamEventOpenCompleted) {
		[_motionManager startDeviceMotionUpdatesToQueue:[NSOperationQueue mainQueue]
								 withHandler:^(CMDeviceMotion *motion, NSError *error) {
									 
									 [self processMotion:motion];
									 
								 }];
	}
}

- (void)processMotion:(CMDeviceMotion *)motion {
	if (!_refAttitude) {
		_refAttitude = [[motion attitude] retain];
	}
	
	[[motion attitude] multiplyByInverseOfAttitude:_refAttitude];
	
	int8_t attitude = ((int8_t) floor(motion.attitude.pitch * 50 / 5)) * 5;
	
	Packet *packet = [[Packet alloc] init];
	packet.turnRatio = attitude;
	packet.power = 75;
	
	if (_prevPacket) {
		if (packet.turnRatio == _prevPacket.turnRatio && packet.power == _prevPacket.power) {
			[packet release];
			return;
		}
	}
	
	_prevPacket = [packet retain];
	[packet release];
	
	NSData *data = [NSKeyedArchiver archivedDataWithRootObject:packet];
	
	[_writeQueue addOperationWithBlock:^{
		
		[_outputStream write:[data bytes] maxLength:[data length]];
		
	}];	
}

- (void)dealloc {
	[_motionManager release];
	[_writeQueue release];
	[_outputStream release];
	[_refAttitude release];
	
	self.statusLabel = nil;
	
    [super dealloc];
}

@end
