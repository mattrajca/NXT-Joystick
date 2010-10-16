//
//  ServerAppDelegate.m
//  Server
//
//  Copyright Matt Rajca 2010. All rights reserved.
//

#import "ServerAppDelegate.h"

#import "MainWindowController.h"
#import <IOBluetoothUI/IOBluetoothUI.h>

@interface ServerAppDelegate ()

- (void)showBTDeviceSelector;

- (void)closedMainWindow:(id)sender;
- (void)cleanupMainWindow;

@end


@implementation ServerAppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
	[self showBTDeviceSelector];
}

- (void)showBTDeviceSelector {
	IOBluetoothDeviceSelectorController *ctrl = [IOBluetoothDeviceSelectorController deviceSelector];
	int res = [ctrl runModal];
	
	if (res != kIOBluetoothUISuccess) {
		if (res == kIOBluetoothUIUserCanceledErr) {
			[NSApp terminate:nil];
		}
		
		return;
	}
	
	NSArray *results = [ctrl getResults];
	
	if ([results count] == 0) {
		[NSApp terminate:nil];
		return;
	}
	
	IOBluetoothDevice *firstDevice = [results objectAtIndex:0];
	
	_mwc = [[MainWindowController alloc] initWithDevice:firstDevice];
	[_mwc showWindow:self];
	
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(closedMainWindow:)
												 name:NSWindowWillCloseNotification
											   object:[_mwc window]];
}

- (void)closedMainWindow:(id)sender {
	[self performSelector:@selector(cleanupMainWindow)
			   withObject:nil
			   afterDelay:0.0f];
}

- (void)cleanupMainWindow {
	_mwc = nil;
	
	[self showBTDeviceSelector];
}

@end
