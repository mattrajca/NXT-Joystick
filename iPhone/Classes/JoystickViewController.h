//
//  JoystickViewController.h
//  Joystick
//
//  Copyright Matt Rajca 2010. All rights reserved.
//

#import "BrowserViewController.h"

@interface JoystickViewController : UIViewController < BrowserViewControllerDelegate, NSStreamDelegate > {
  @private
	CMMotionManager *_motionManager;
	NSOperationQueue *_writeQueue;
	NSOutputStream *_outputStream;
	CMAttitude *_refAttitude;
	BOOL _displayedOnce;
}

@property (nonatomic, retain) IBOutlet UILabel *statusLabel;

@end

