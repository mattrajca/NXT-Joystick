//
//  JoystickAppDelegate.h
//  Joystick
//
//  Copyright Matt Rajca 2010. All rights reserved.
//

@class JoystickViewController;

@interface JoystickAppDelegate : NSObject < UIApplicationDelegate > {

}

@property (nonatomic, retain) IBOutlet UIWindow *window;
@property (nonatomic, retain) IBOutlet JoystickViewController *viewController;

@end

