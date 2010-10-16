//
//  JoystickViewController.m
//  Joystick
//
//  Copyright Matt Rajca 2010. All rights reserved.
//

#import "JoystickViewController.h"

#import "Packet.h"

@interface JoystickViewController ()

- (void)showBrowser:(NSNumber *)animated; /* BOOL */
- (void)enteredBackground:(NSNotification *)not;
- (void)stopClient;
- (void)processMotion:(CMDeviceMotion *)motion;

@end


@implementation JoystickViewController

@synthesize statusLabel;

// BK: http://www.flickr.com/photos/torley/2587091353/

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
		[self performSelector:@selector(showBrowser:)
				   withObject:[NSNumber numberWithBool:YES]
				   afterDelay:0.25f];
		
		_displayedOnce = YES;
	}
}

- (void)showBrowser:(NSNumber *)animated {
	[[NSNotificationCenter defaultCenter] removeObserver:self
													name:UIApplicationWillResignActiveNotification
												  object:[UIApplication sharedApplication]];
	
	BrowserViewController *vc = [[BrowserViewController alloc] init];
	vc.delegate = self;
	vc.serviceType = @"_nxtjoystick._tcp.";
	vc.domain = @"";
	
	UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:vc];
	[vc release];
	
	[self presentModalViewController:nav animated:[animated boolValue]];
	[nav release];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    return interfaceOrientation == UIInterfaceOrientationLandscapeRight;
}

- (void)enteredBackground:(NSNotification *)not {
	if (_outputStream) {
		[self stopClient];
		[self showBrowser:nil];
	}
}

- (void)browserViewController:(BrowserViewController *)bvc
			didResolveService:(NSNetService *)service {
	
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(enteredBackground:)
												 name:UIApplicationWillResignActiveNotification
											   object:[UIApplication sharedApplication]];
	
	[service getInputStream:NULL outputStream:&_outputStream];
	
	[_outputStream retain];
	[_outputStream setDelegate:self];
	[_outputStream scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSRunLoopCommonModes];
	[_outputStream open];
}

- (void)stopClient {
	[_motionManager stopDeviceMotionUpdates];
	
	[_outputStream close];
	[_outputStream release];
	_outputStream = nil;
	
	[_refAttitude release];
	_refAttitude = nil;
}

- (void)stream:(NSStream *)aStream handleEvent:(NSStreamEvent)eventCode {
	if (eventCode == NSStreamEventOpenCompleted) {
		[_motionManager startDeviceMotionUpdatesToQueue:[NSOperationQueue mainQueue]
								 withHandler:^(CMDeviceMotion *motion, NSError *error) {
									 
									 [self processMotion:motion];
									 
								 }];
	}
	else if (eventCode == NSStreamEventEndEncountered ||
			 eventCode == NSStreamEventErrorOccurred) {
		
		[self performSelectorOnMainThread:@selector(stopClient) withObject:nil waitUntilDone:NO];
		
		[self performSelectorOnMainThread:@selector(showBrowser:)
							   withObject:[NSNumber numberWithBool:YES]
							waitUntilDone:NO];
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
		
		if (!_outputStream)
			return;
		
		[_outputStream write:[data bytes] maxLength:[data length]];
		
	}];	
}

- (IBAction)stop:(id)sender {
	[self stopClient];
	[self showBrowser:[NSNumber numberWithBool:YES]];
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
