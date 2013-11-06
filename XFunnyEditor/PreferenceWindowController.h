//
//  PreferenceWindowController.h
//  XFunnyEditor
//
//  Created by Kenji Abe on 2013/09/26.
//  Copyright (c) 2013年 STAR-ZERO. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@protocol PreferenceDelegate <NSObject>

@required
- (void)selectedImageFile:(NSString *)imagePath;
- (void)selectedPosition:(NSImageAlignment)position;
- (void)selectedOpacity:(float)opacity;
- (void)selectedTimeInterval:(NSTimeInterval)interval;
- (void)selectedRandomOrder:(BOOL)random;

@end

@interface PreferenceWindowController : NSWindowController<NSWindowDelegate>

@property (assign) IBOutlet NSTextField *textFile;
@property (assign) IBOutlet NSButton *buttonFile;
@property (assign) IBOutlet NSPopUpButton *imagePosition;
@property (assign) IBOutlet NSSlider *sliderOpacity;
@property (assign) IBOutlet NSTextField *labelOpacity;
@property (nonatomic, assign) id<PreferenceDelegate> delegate;
@property (assign) IBOutlet NSButton *pictureTimerBox;
@property (assign) IBOutlet NSTextField *timerValue;
@property (assign) IBOutlet NSButton *randomOrder;

- (IBAction)clickFile:(id)sender;
- (IBAction)changePosition:(id)sender;
- (IBAction)changeSliderOpactiy:(id)sender;
- (IBAction)onEnablePictureTimer:(NSButton *)sender;
- (IBAction)onSetTimerValue:(NSTextField *)sender;
- (IBAction)onSetRandomOrder:(NSButton *)sender;

@end
