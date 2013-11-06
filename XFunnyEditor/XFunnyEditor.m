//
//  XFunnyEditor.m
//  XFunnyEditor
//
//  Created by Kenji Abe on 2013/07/27.
//  Copyright (c) 2013年 STAR-ZERO. All rights reserved.
//

#import "XFunnyEditor.h"

static NSString * const kUserDefaultsKeyImagePath               = @"XFunnyEditoryImagePath";
static NSString * const kUserDefaultsKeyImagePosition           = @"XFunnyEditoryImagePosition";
static NSString * const kUserDefaultsKeyImageOpcity             = @"XFunnyEditoryImageOpacity";
static NSString * const kUserDefaultsKeyImageChangeInterval     = @"XFunnyEditoryImageChangeInterval";
static NSString * const kUserDefaultsKeyImageRandomOrder        = @"XFunnyEditoryImageRandomOrder";
static NSString * const kUserDefaultsKeyImageSize               = @"XFunnyEditoryImageSize";

@interface XFunnyEditor()

@property (nonatomic, retain) NSTimer                       *timer;
@property (nonatomic, assign) CGFloat                       opacity;
@property (nonatomic, assign) NSImageAlignment              position;
@property (nonatomic, assign) NSTimeInterval                changeInterval;
@property (nonatomic, assign) BOOL                          randomOrder;
@property (nonatomic, assign) NSRect                        sidebarRect;
@property (nonatomic, assign) NSSize                        imageSize;
@property (nonatomic, retain) NSColor                       *originalColor;
@property (nonatomic, retain) NSImage                       *image;
@property (nonatomic, retain) PreferenceWindowController    *preferenceWindow;
@property (nonatomic, retain) DVTSourceTextView             *currentTextView;

@end

@implementation XFunnyEditor

#pragma mark -
#pragma mark Class Methods

+ (void)pluginDidLoad:(NSBundle *)plugin
{
    NSLog(@"XFunnyEditor Plugin loaded");
    static id sharedPlugin = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedPlugin = [[self alloc] init];
    });
}

#pragma mark -
#pragma mark Initializations And Deallocations

- (void)dealloc {
    self.timer = nil;
    self.originalColor = nil;
    self.image = nil;
    self.preferenceWindow = nil;
    self.currentTextView = nil;
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [super dealloc];
}

- (id)init {
    if (self = [super init]) {
        NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
        self.position = [userDefaults integerForKey:kUserDefaultsKeyImagePosition];
        self.opacity = [userDefaults floatForKey:kUserDefaultsKeyImageOpcity];
        self.changeInterval = [userDefaults floatForKey:kUserDefaultsKeyImageChangeInterval];
        self.randomOrder = [userDefaults boolForKey:kUserDefaultsKeyImageRandomOrder];
        NSData *sizeData = [userDefaults valueForKey:kUserDefaultsKeyImageSize];
        NSValue *sizeValue = [NSKeyedUnarchiver unarchiveObjectWithData:sizeData];
        self.imageSize = [sizeValue sizeValue];
        if (self.opacity == 0) {
            self.opacity = 1;
        }
        
        [self updateBackgroundImage];
        
        // Sample Menu Item:
        NSMenuItem *menuItem = [[NSApp mainMenu] itemWithTitle:@"Edit"];
        if (menuItem) {
            [[menuItem submenu] addItem:[NSMenuItem separatorItem]];
            NSMenuItem *actionMenuItem = [[NSMenuItem alloc] initWithTitle:@"XFunnyEditor" action:@selector(doMenuAction:) keyEquivalent:@""];
            [actionMenuItem setTarget:self];
            
            if (self.image) {
                [actionMenuItem setState:NSOnState];
            } else {
                [actionMenuItem setState:NSOffState];
            }
            
            [[menuItem submenu] addItem:actionMenuItem];
            [actionMenuItem release];
        }
        
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(applicationDidFinishLaunching:)
                                                     name:NSApplicationDidFinishLaunchingNotification
                                                   object:nil];
        
    }
    return self;
}

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(viewFrameDidChangeNotification:)
                                                 name:NSViewFrameDidChangeNotification
                                               object:nil];
    [self scheduleImageChangingTimerWithInterval:self.changeInterval];
}

#pragma mark -
#pragma mark Accessors

- (void)setTimer:(NSTimer *)timer {
    if (_timer != timer) {
        [_timer invalidate];
        [_timer release];
        _timer = [timer retain];
        // try to save some power on OS X 10.9 and above
        if ([_timer respondsToSelector:@selector(setTolerance:)]) {
            _timer.tolerance = _timer.timeInterval * 0.1f;
        }
    }
}

- (void)viewFrameDidChangeNotification:(NSNotification *)notification {
    // keep current object
    if ([[notification object] isKindOfClass:[DVTSourceTextView class]]) {
        self.currentTextView = (DVTSourceTextView *)[notification object];
    } else if ([[notification object] isKindOfClass:[DVTTextSidebarView class]]) {
        self.sidebarRect = ((DVTTextSidebarView *)[notification object]).frame;
    }
    
    if (self.image == nil) {
        return;
    }
    
    if ([[notification object] isKindOfClass:[DVTSourceTextView class]]) {
        DVTSourceTextView *textView = (DVTSourceTextView *)[notification object];
        DVTSourceTextScrollView *scrollView = (DVTSourceTextScrollView *)[textView enclosingScrollView];
        NSView *view = [scrollView superview];
        if (view) {
            if (NSEqualRects(self.sidebarRect, NSZeroRect)) {
                return;
            }
            
            NSImageView *imageView = [self getImageViewFromParentView:view];
            XFunnyBackgroundView *backgroundView = [self getBackgroundViewFromaParentView:view];
            if (imageView) {
                // exist image
                [self setFrameImageView:imageView backgroundView:backgroundView scrollView:scrollView];
                if (NSEqualSizes(self.imageSize, NSMakeSize(0, 0)) == NO) {
                    self.image.size = self.imageSize;
                }
                [imageView setImage:self.image];
                return;
            }
            
            NSColor *color = [textView backgroundColor];
            self.originalColor = color;
            [scrollView setDrawsBackground:NO];
            [textView setBackgroundColor:[NSColor clearColor]];
            
            // create ImageView
            imageView = [[[NSImageView alloc] initWithFrame:[self getImageViewFrame:scrollView]] autorelease];
            
            backgroundView = [[[XFunnyBackgroundView alloc] initWithFrame:[self getImageViewFrame:scrollView] color:color] autorelease];
            
            if (NSEqualSizes(self.imageSize, NSMakeSize(0, 0)) == NO) {
                self.image.size = self.imageSize;
            }
            [imageView setImage:self.image];
            imageView.alphaValue = self.opacity;
            imageView.imageAlignment = self.position;
            [view addSubview:imageView positioned:NSWindowBelow relativeTo:nil];
            [view addSubview:backgroundView positioned:NSWindowBelow relativeTo:nil];
        }
        
    } else if ([[notification object] isKindOfClass:[DVTSourceTextScrollView class]]) {
        // resize editor
        DVTSourceTextScrollView *scrollView = [notification object];
        NSView *view = [scrollView superview];
        
        NSImageView *imageView = [self getImageViewFromParentView:view];
        XFunnyBackgroundView *backgroundView = [self getBackgroundViewFromaParentView:view];
        
        // set frame
        [self setFrameImageView:imageView backgroundView:backgroundView scrollView:scrollView];
    }
}

- (NSImageView *)getImageViewFromParentView:(NSView *)parentView {
    for (NSView *subView in [parentView subviews]) {
        if ([subView isKindOfClass:[NSImageView class]]) {
            return (NSImageView *) subView;
        }
    }
    return nil;
}

- (NSImageView *)getImageViewFromTextView {
    
    DVTSourceTextScrollView *scrollView = (DVTSourceTextScrollView *)[self.currentTextView enclosingScrollView];
    NSView *view = [scrollView superview];
    if (view) {
        return [self getImageViewFromParentView:view];
    }
    
    return nil;
}

- (XFunnyBackgroundView *)getBackgroundViewFromaParentView:(NSView *)parentView {
    for (NSView *subView in [parentView subviews]) {
        if ([subView isKindOfClass:[XFunnyBackgroundView class]]) {
            return (XFunnyBackgroundView *) subView;
        }
    }
    return nil;
}

- (NSRect)getImageViewFrame:(NSView *)scrollView {
    return NSMakeRect(self.sidebarRect.size.width,
                      0,
                      scrollView.bounds.size.width - self.sidebarRect.size.width,
                      self.sidebarRect.size.height);
}

- (void)setFrameImageView:(NSImageView *)imageView
           backgroundView:(XFunnyBackgroundView *)backgroundView
               scrollView:(DVTSourceTextScrollView *)scrollView{
    if (imageView && backgroundView) {
        [imageView setFrame:[self getImageViewFrame:scrollView]];
        [backgroundView setFrame:[self getImageViewFrame:scrollView]];
    }
}

// menu action
- (void)doMenuAction:(id)sender {
    NSMenuItem *menuItem = (NSMenuItem *)sender;
    if ([menuItem state] == NSOnState){
        [self disableBackgroundImage:menuItem];
    } else {
        [self enableBackgroundImage:menuItem];
    }
}

// disable background image
- (void)disableBackgroundImage:(NSMenuItem *)menuItem {
    DVTSourceTextScrollView *scrollView = (DVTSourceTextScrollView *)[self.currentTextView enclosingScrollView];
    NSView *view = [scrollView superview];
    NSImageView *imageView = [self getImageViewFromParentView:view];
    XFunnyBackgroundView *backgroundView = [self getBackgroundViewFromaParentView:view];
    if (imageView) {
        // remove image
        [self.currentTextView setBackgroundColor:self.originalColor];
        [imageView removeFromSuperview];
        [backgroundView removeFromSuperview];
    }
    
    [self removeUserDefaults];
    
    self.image = nil;
    self.position = 0;
    self.opacity = 1;
    [menuItem setState:NSOffState];
}

// selection image file
- (void)enableBackgroundImage:(NSMenuItem *)menuItem {
    if (!self.preferenceWindow) {
        self.preferenceWindow = [[[PreferenceWindowController alloc] initWithWindowNibName:@"PreferenceWindowController"] autorelease];
        self.preferenceWindow.delegate = self;
    }
    [self.preferenceWindow.textFile setStringValue:@""];
    [self.preferenceWindow.sliderOpacity setIntValue:100];
    [self.preferenceWindow.labelOpacity setStringValue:@"100"];
    
    NSInteger result = [[NSApplication sharedApplication] runModalForWindow:[self.preferenceWindow window]];
    [[self.preferenceWindow window] orderOut:self];
    
    if (result == 0) {
        [menuItem setState:NSOnState];
        
        // save userdefaults
        NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
        [userDefaults setObject:self.preferenceWindow.textFile.stringValue forKey:kUserDefaultsKeyImagePath];
        [userDefaults setInteger:self.position forKey:kUserDefaultsKeyImagePosition];
        [userDefaults setFloat:self.opacity forKey:kUserDefaultsKeyImageOpcity];
        [userDefaults setFloat:self.changeInterval forKey:kUserDefaultsKeyImageChangeInterval];
        [userDefaults setBool:self.randomOrder forKey:kUserDefaultsKeyImageRandomOrder];
        NSValue *sizeValue = [NSValue valueWithSize:self.imageSize];
        NSData *sizedata = [NSKeyedArchiver archivedDataWithRootObject:sizeValue];
        [userDefaults setValue:sizedata forKey:kUserDefaultsKeyImageSize];
        [userDefaults synchronize];
    } else {
        self.timer = nil;
    }
    
}

- (void)updateBackgroundImage {
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    NSString *imagePath = [userDefaults objectForKey:kUserDefaultsKeyImagePath];
    
    if (imagePath) {
        NSString *path = [self imagePathForSelectedPath:imagePath];
        if (path) {
            self.image = [[[NSImage alloc] initWithContentsOfFile:path] autorelease];
        }
    }
    [[NSNotificationCenter defaultCenter] postNotificationName:NSViewFrameDidChangeNotification object:self.currentTextView];
}

- (void)removeUserDefaults {
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    [userDefaults removeObjectForKey:kUserDefaultsKeyImagePath];
    [userDefaults removeObjectForKey:kUserDefaultsKeyImagePosition];
    [userDefaults removeObjectForKey:kUserDefaultsKeyImageOpcity];
    [userDefaults synchronize];
    
}

#pragma mark -
#pragma mark PreferenceDelegate Methods

- (void)selectedTimeInterval:(NSTimeInterval)interval {
    self.changeInterval = interval;
    [self scheduleImageChangingTimerWithInterval:interval];
}

- (void)selectedRandomOrder:(BOOL)random {
    self.randomOrder = random;
}

- (void)selectedImageFile:(NSString *)imagePath {
    NSString *path = [self imagePathForSelectedPath:imagePath];
    self.image = [[[NSImage alloc] initWithContentsOfFile:path] autorelease];
    if (self.currentTextView) {
        // post notification
        [[NSNotificationCenter defaultCenter] postNotificationName:NSViewFrameDidChangeNotification object:self.currentTextView];
    }
}

- (void)selectedPosition:(NSImageAlignment)position {
    self.position = position;
    NSImageView *imageView = [self getImageViewFromTextView];
    if (imageView) {
        imageView.imageAlignment = position;
    }
    
}

- (void)selectedOpacity:(float)opacity {
    self.opacity = opacity;
    NSImageView *imageView = [self getImageViewFromTextView];
    if (imageView) {
        imageView.alphaValue = opacity;
    }
}


- (void)selectedImageSize:(NSSize)size {
    self.imageSize = size;
    self.image.size = size;
}
#pragma mark -
#pragma mark Private

- (void)scheduleImageChangingTimerWithInterval:(NSTimeInterval)interval {
    self.changeInterval = interval;
    if (interval) {
        self.timer = [NSTimer scheduledTimerWithTimeInterval:interval
                                                      target:self
                                                    selector:@selector(updateBackgroundImage)
                                                    userInfo:nil
                                                     repeats:YES];

    }
}

- (NSString *)imagePathForSelectedPath:(NSString *)path {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    BOOL isDirectory = NO;
    if ([fileManager fileExistsAtPath:path isDirectory:&isDirectory]) {
        if (isDirectory) {
            NSError *error;
            NSArray *contents = [fileManager contentsOfDirectoryAtURL:[NSURL fileURLWithPath:path]
                                           includingPropertiesForKeys:@[NSURLTypeIdentifierKey]
                                                              options:NSDirectoryEnumerationSkipsHiddenFiles
                                                                error:&error];
            NSMutableArray *res = [NSMutableArray array];
            for (NSURL *f in contents) {
                NSString *s = nil;
                if ([f getResourceValue:&s forKey:NSURLTypeIdentifierKey error:nil]) {
                    if ([s isEqualToString:@"public.jpeg"] || [s isEqualToString:@"public.png"]) {
                        [res addObject:[f path]];
                    }
                }
            }
            return res[arc4random() % [res count]];
        } else {
            return path;
        }
    }
    return nil;
}

@end
