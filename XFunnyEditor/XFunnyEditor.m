//
//  XFunnyEditor.m
//  XFunnyEditor
//
//  Created by Kenji Abe on 2013/07/27.
//  Copyright (c) 2013年 STAR-ZERO. All rights reserved.
//

#import "XFunnyEditor.h"

static NSString * const kUserDefaultsKeyImagePath = @"XFunnyEditoryImagePath";
static NSString * const kUserDefaultsKeyImagePosition = @"XFunnyEditoryImagePosition";
static NSString * const kUserDefaultsKeyImageOpcity = @"XFunnyEditoryImageOpacity";

@interface XFunnyEditor()

@property (nonatomic, retain) NSTimer *timer;

@end

@implementation XFunnyEditor
{
    PreferenceWindowController *_preferenceWindow;
    NSImage *_image;
    NSUInteger _position;
    float _opacity;
    NSRect _sidebarRect;
    DVTSourceTextView *_currentTextView;
    NSColor *_originalColor;
}

@synthesize timer = _timer;

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
#pragma mark Initializations

- (id)init
{
    if (self = [super init]) {
        NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
        NSString *imagePath = [userDefaults objectForKey:kUserDefaultsKeyImagePath];
        
        if (imagePath) {
            NSString *path = [self imagePathForSelectedPath:imagePath];
            if (path) {
                _image = [[NSImage alloc] initWithContentsOfFile:path];
            } else {
                [self removeUserDefaults];
            }
        }
        
        _position = [userDefaults integerForKey:kUserDefaultsKeyImagePosition];
        _opacity = [userDefaults floatForKey:kUserDefaultsKeyImageOpcity];
        
        if (_opacity == 0) {
            _opacity = 1;
        }
        
        // Sample Menu Item:
        NSMenuItem *menuItem = [[NSApp mainMenu] itemWithTitle:@"Edit"];
        if (menuItem) {
            [[menuItem submenu] addItem:[NSMenuItem separatorItem]];
            NSMenuItem *actionMenuItem = [[NSMenuItem alloc] initWithTitle:@"XFunnyEditor" action:@selector(doMenuAction:) keyEquivalent:@""];
            [actionMenuItem setTarget:self];

            if (_image) {
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

- (void)applicationDidFinishLaunching:(NSNotification *)notification
{
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(viewFrameDidChangeNotification:)
                                                 name:NSViewFrameDidChangeNotification
                                               object:nil];
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

- (void)viewFrameDidChangeNotification:(NSNotification *)notification
{
    // keep current object
    if ([[notification object] isKindOfClass:[DVTSourceTextView class]]) {
        _currentTextView = (DVTSourceTextView *)[notification object];
    } else if ([[notification object] isKindOfClass:[DVTTextSidebarView class]]) {
        _sidebarRect = ((DVTTextSidebarView *)[notification object]).frame;
    }

    if (_image == nil) {
        return;
    }

    if ([[notification object] isKindOfClass:[DVTSourceTextView class]]) {
        DVTSourceTextView *textView = (DVTSourceTextView *)[notification object];
        DVTSourceTextScrollView *scrollView = (DVTSourceTextScrollView *)[textView enclosingScrollView];
        NSView *view = [scrollView superview];
        if (view) {
            if (NSEqualRects(_sidebarRect, NSZeroRect)) {
                return;
            }

            NSImageView *imageView = [self getImageViewFromParentView:view];
            XFunnyBackgroundView *backgroundView = [self getBackgroundViewFromaParentView:view];
            if (imageView) {
                // exist image
                [self setFrameImageView:imageView backgroundView:backgroundView scrollView:scrollView];
                [imageView setImage:_image];
                return;
            }

            NSColor *color = [textView backgroundColor];
            _originalColor = color;
            [scrollView setDrawsBackground:NO];
            [textView setBackgroundColor:[NSColor clearColor]];

            // create ImageView
            imageView = [[[NSImageView alloc] initWithFrame:[self getImageViewFrame:scrollView]] autorelease];
            
            backgroundView = [[[XFunnyBackgroundView alloc] initWithFrame:[self getImageViewFrame:scrollView] color:color] autorelease];

            [imageView setImage:_image];
            imageView.alphaValue = _opacity;
            imageView.imageAlignment = _position;
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

- (NSImageView *)getImageViewFromParentView:(NSView *)parentView
{
    for (NSView *subView in [parentView subviews]) {
        if ([subView isKindOfClass:[NSImageView class]]) {
            return (NSImageView *) subView;
        }
    }
    return nil;
}

- (NSImageView *)getImageViewFromTextView
{
    
    DVTSourceTextScrollView *scrollView = (DVTSourceTextScrollView *)[_currentTextView enclosingScrollView];
    NSView *view = [scrollView superview];
    if (view) {
        return [self getImageViewFromParentView:view];
    }
    
    return nil;
}

- (XFunnyBackgroundView *)getBackgroundViewFromaParentView:(NSView *)parentView
{
    for (NSView *subView in [parentView subviews]) {
        if ([subView isKindOfClass:[XFunnyBackgroundView class]]) {
            return (XFunnyBackgroundView *) subView;
        }
    }
    return nil;
}

- (NSRect)getImageViewFrame:(NSView *)scrollView
{
    return NSMakeRect(_sidebarRect.size.width,
                      0,
                      scrollView.bounds.size.width - _sidebarRect.size.width,
                      _sidebarRect.size.height);
}

- (void)setFrameImageView:(NSImageView *)imageView backgroundView:(XFunnyBackgroundView *)backgroundView scrollView:(DVTSourceTextScrollView *)scrollView
{
    if (imageView && backgroundView) {
        [imageView setFrame:[self getImageViewFrame:scrollView]];
        [backgroundView setFrame:[self getImageViewFrame:scrollView]];
    }
}

// menu action
- (void)doMenuAction:(id)sender
{
    NSMenuItem *menuItem = (NSMenuItem *)sender;
    if ([menuItem state] == NSOnState){
        [self disableBackgroundImage:menuItem];
    } else {
        [self enableBackgroundImage:menuItem];
    }
}

// disable background image
- (void)disableBackgroundImage:(NSMenuItem *)menuItem
{
    DVTSourceTextScrollView *scrollView = (DVTSourceTextScrollView *)[_currentTextView enclosingScrollView];
    NSView *view = [scrollView superview];
    NSImageView *imageView = [self getImageViewFromParentView:view];
    XFunnyBackgroundView *backgroundView = [self getBackgroundViewFromaParentView:view];
    if (imageView) {
        // remove image
        [_currentTextView setBackgroundColor:_originalColor];
        [imageView removeFromSuperview];
        [backgroundView removeFromSuperview];
    }

    [self removeUserDefaults];
    
    if (_image) {
        [_image release];
        _image = nil;
    }
    _position = 0;
    _opacity = 1;
    [menuItem setState:NSOffState];
}

// selection image file
- (void)enableBackgroundImage:(NSMenuItem *)menuItem
{
    
    if (!_preferenceWindow) {
        _preferenceWindow = [[PreferenceWindowController alloc] initWithWindowNibName:@"PreferenceWindowController"];
        _preferenceWindow.delegate = self;
    }
    [_preferenceWindow.textFile setStringValue:@""];
    [_preferenceWindow.sliderOpacity setIntValue:100];
    [_preferenceWindow.labelOpacity setStringValue:@"100"];
    
    NSInteger result = [[NSApplication sharedApplication] runModalForWindow:[_preferenceWindow window]];
    [[_preferenceWindow window] orderOut:self];
    
    if (result == 0) {
        [menuItem setState:NSOnState];
        
        // save userdefaults
        NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
        [userDefaults setObject:_preferenceWindow.textFile.stringValue forKey:kUserDefaultsKeyImagePath];
        [userDefaults setInteger:_position forKey:kUserDefaultsKeyImagePosition];
        [userDefaults setFloat:_opacity forKey:kUserDefaultsKeyImageOpcity];
        [userDefaults synchronize];
    }

}

- (void)removeUserDefaults
{
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    [userDefaults removeObjectForKey:kUserDefaultsKeyImagePath];
    [userDefaults removeObjectForKey:kUserDefaultsKeyImagePosition];
    [userDefaults removeObjectForKey:kUserDefaultsKeyImageOpcity];
    [userDefaults synchronize];
    
}

#pragma mark -
#pragma mark PreferenceDelegate Methods

- (void)selectedTimeInterval:(NSTimeInterval)interval {
    
}

- (void)selectedRandomOrder:(BOOL)random {
    
}

- (void)selectedImageFile:(NSString *)imagePath
{
    NSString *path = [self imagePathForSelectedPath:imagePath];
    _image = [[NSImage alloc] initWithContentsOfFile:path];
    if (_currentTextView) {
        // post notification
        [[NSNotificationCenter defaultCenter] postNotificationName:NSViewFrameDidChangeNotification object:_currentTextView];
    }
}

- (void)selectedPosition:(NSImageAlignment)position
{
    _position = position;
    NSImageView *imageView = [self getImageViewFromTextView];
    if (imageView) {
        imageView.imageAlignment = position;
    }
    
}
- (void)selectedOpacity:(float)opacity
{
    _opacity = opacity;
    NSImageView *imageView = [self getImageViewFromTextView];
    if (imageView) {
        imageView.alphaValue = opacity;
    }
}

#pragma mark -
#pragma mark Private

- (NSString *)imagePathForSelectedPath:(NSString *)path
{
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

#pragma mark -
#pragma mark Deallocations

- (void)dealloc
{
    self.timer = nil;
    [_image release];
    [_currentTextView release];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [super dealloc];
}

@end
