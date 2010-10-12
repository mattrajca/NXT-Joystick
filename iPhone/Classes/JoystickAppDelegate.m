//
//  JoystickAppDelegate.m
//  Joystick
//
//  Copyright Matt Rajca 2010. All rights reserved.
//

#import "JoystickAppDelegate.h"

#import "JoystickViewController.h"

@implementation JoystickAppDelegate

@synthesize window, viewController;

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
	[window addSubview:viewController.view];
	[window makeKeyAndVisible];
	
	return YES;
}

- (void)dealloc {
	self.viewController = nil;
	self.window = nil;
	
	[super dealloc];
}

@end
