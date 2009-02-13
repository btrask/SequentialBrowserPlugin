/* Copyright © 2007-2008 The Sequential Project. All rights reserved.

Permission is hereby granted, free of charge, to any person obtaining a
copy of this software and associated documentation files (the "Software"),
to deal with the Software without restriction, including without limitation
the rights to use, copy, modify, merge, publish, distribute, sublicense,
and/or sell copies of the Software, and to permit persons to whom the
Software is furnished to do so, subject to the following conditions:
1. Redistributions of source code must retain the above copyright notice,
   this list of conditions and the following disclaimers.
2. Redistributions in binary form must reproduce the above copyright
   notice, this list of conditions and the following disclaimers in the
   documentation and/or other materials provided with the distribution.
3. Neither the name of The Sequential Project nor the names of its
   contributors may be used to endorse or promote products derived from
   this Software without specific prior written permission.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL
THE CONTRIBUTORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR
OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
DEALINGS WITH THE SOFTWARE. */
#import "SBPController.h"

// Classes
#import "SBPDocumentRepresentation.h"
#import "SBPDocumentView.h"

// Other Sources
#import "NSMenuAdditions.h"
#import "NSObjectAdditions.h"
#import "NSViewAdditions.h"

static NSArray *(*SBPOriginalContextMenuIMP)(id, SEL, WebView *, NSDictionary *, NSArray *);
static void (*SBPOriginalSetLinkHoverTextIMP)(id, SEL, NSString *);
static BOOL (*SBPOriginalValidateMenuItemIMP)(id, SEL, NSMenuItem *);
static id (*SBPOriginalWindowInitIMP)(id, SEL, NSRect, NSUInteger, NSBackingStoreType, BOOL);

@interface SBPController (Private)

+ (NSMenuItem *)_menuItemWithTitle:(NSString *)title representedObject:(id)anObject action:(SEL)action;

@end

@interface NSObject (SBP_OWMethods)

// OWBrowserController
- (NSString *)documentTitle;
- (void)setWindowTitle:(NSString *)aString;
- (BOOL)statusBarVisible;
- (id)siteEditor;

// OWSiteEditor
- (id)sitePreferencesController;

// OWSitePreferencesController (Private)
- (id)_preferenceForKey:(NSString *)aString;

// OWSitePreference
- (BOOL)boolValue;
- (void)setBoolValue:(BOOL)flag;

@end

@implementation SBPController

#pragma mark Class Methods

+ (id)sharedController
{
	static SBPController *c = nil;
	if(!c) c = [[self alloc] init];
	return c;
}
+ (NSArray *)supportedMIMETypes
{
	return [NSArray arrayWithObjects:@"application/pdf", @"application/x-pdf", @"application/acrobat", @"applications/vnd.pdf", @"text/pdf", @"text/x-pdf", @"application/postscript", @"image/tiff", @"image/raw", @"image/exr", @"image/bmp", @"image/x-bmp", @"image/x-windows-bmp", @"image/ms-bmp", @"image/x-ms-bmp", @"application/bmp", @"image/gif", @"image/jpeg", @"image/jpg", @"image/pjpeg", @"image/pict", @"image/x-pict", @"image/png", @"application/png", @"application/x-png", @"image/photoshop", @"image/x-photoshop", @"image/psd", @"application/photoshop", @"application/psd", nil];
}

#pragma mark Private Protocol

+ (NSMenuItem *)_menuItemWithTitle:(NSString *)title
                representedObject:(id)anObject
                action:(SEL)action
{
	NSMenuItem *const item = [[[NSMenuItem alloc] init] autorelease];
	[item setTitle:title];
	[item setRepresentedObject:anObject];
	[item setTarget:[self sharedController]];
	[item setAction:action];
	return item;
}

#pragma mark NSObject

+ (void)load
{
	if(floor(NSAppKitVersionNumber) <= NSAppKitVersionNumber10_4) return;

	NSString *const ident = [[NSBundle mainBundle] bundleIdentifier];
	SEL viewSourceSelector = NULL;
	Class UIDelegateClass = Nil;
	NSMenu *menu = nil;
	NSUInteger index = 0;
	NSBundle *const bundle = [NSBundle bundleForClass:self];

	if([@"com.apple.Safari" isEqualToString:ident]) {
		viewSourceSelector = @selector(viewSource:);
		UIDelegateClass = NSClassFromString(@"BrowserWebView");
	} else if([@"com.omnigroup.OmniWeb5" isEqualToString:ident]) {
		viewSourceSelector = @selector(viewSource:);
		UIDelegateClass = NSClassFromString(@"OWTab");
		Class const browserControllerClass = NSClassFromString(@"OWBrowserController");
		SBPOriginalSetLinkHoverTextIMP = (void (*)(id, SEL, NSString *))[browserControllerClass SBP_useImplementationFromClass:self forSelector:@selector(setLinkHoverText:)];
		SBPOriginalWindowInitIMP = (id (*)(id, SEL, NSRect, NSUInteger, NSBackingStoreType, BOOL))[NSClassFromString(@"OWBrowserWindow") SBP_useImplementationFromClass:self forSelector:@selector(initWithContentRect:styleMask:backing:defer:)];
		if([[NSApp mainMenu] SBP_getMenu:&menu index:&index ofItemWithTarget:nil action:@selector(toggleSitePreferences:)]) {
			NSMenuItem *const jsItem = [self _menuItemWithTitle:NSLocalizedStringFromTableInBundle(@"Turn JavaScript On", nil, bundle, nil) representedObject:nil action:@selector(SBP_toggleJavaScriptEnabled:)];
			[jsItem setTarget:nil];
			[jsItem setKeyEquivalent:@"x"];
			[jsItem setKeyEquivalentModifierMask:NSCommandKeyMask | NSAlternateKeyMask];
			[menu insertItem:jsItem atIndex:index + 1];
			(void)[browserControllerClass SBP_useImplementationFromClass:self forSelector:@selector(SBP_toggleJavaScriptEnabled:)];
			SBPOriginalValidateMenuItemIMP = (BOOL (*)(id, SEL, NSMenuItem *))[browserControllerClass SBP_useImplementationFromClass:self originalSelector:@selector(SBP_validateMenuItem:) forSelector:@selector(validateMenuItem:)];
		}
	} else if([@"jp.hmdt.shiira" isEqualToString:ident]) {
		viewSourceSelector = @selector(viewPageSourceAction:);
		UIDelegateClass = NSClassFromString(@"SRPageController");
	} else return;

	if([[NSApp mainMenu] SBP_getMenu:&menu index:&index ofItemWithTarget:nil action:viewSourceSelector]) {
		NSMenuItem *const foregroundItem = [self _menuItemWithTitle:NSLocalizedStringFromTableInBundle(@"View with Sequential", nil, bundle, nil) representedObject:nil action:@selector(viewCurrentPageInSequentialInForeground:)];
		[foregroundItem setKeyEquivalent:@"u"];
		[foregroundItem setKeyEquivalentModifierMask:NSCommandKeyMask | NSControlKeyMask];
		[menu insertItem:foregroundItem atIndex:index];

		NSMenuItem *const backgroundItem = [self _menuItemWithTitle:NSLocalizedStringFromTableInBundle(@"View with Sequential in Background", nil, bundle, nil) representedObject:nil action:@selector(viewCurrentPageInSequentialInBackground:)];
		[backgroundItem setKeyEquivalent:@"u"];
		[backgroundItem setKeyEquivalentModifierMask:NSCommandKeyMask | NSControlKeyMask | NSShiftKeyMask];
		[backgroundItem setAlternate:YES];
		[menu insertItem:backgroundItem atIndex:index + 1];
	}

	NSString *MIMEType;
	NSEnumerator *const MIMETypeEnum = [[self supportedMIMETypes] objectEnumerator];
	while((MIMEType = [MIMETypeEnum nextObject])) [WebView registerViewClass:[SBPDocumentView class] representationClass:[SBPDocumentRepresentation class] forMIMEType:MIMEType];

	SBPOriginalContextMenuIMP = (NSArray *(*)(id, SEL, WebView *, NSDictionary *, NSArray *))[UIDelegateClass SBP_useImplementationFromClass:self forSelector:@selector(webView:contextMenuItemsForElement:defaultMenuItems:)];
}

#pragma mark Instance Methods

- (IBAction)viewCurrentPageInSequentialInForeground:(id)sender
{
	[self openSequentialWithCurrentPageInBackground:NO];
}
- (IBAction)viewCurrentPageInSequentialInBackground:(id)sender
{
	[self openSequentialWithCurrentPageInBackground:YES];
}
- (IBAction)viewLinkInSequentialInForeground:(id)sender
{
	if(![self openSequentialWithURL:[sender representedObject] inBackground:NO]) NSBeep();
}
- (IBAction)viewLinkInSequentialInBackground:(id)sender
{
	if(![self openSequentialWithURL:[sender representedObject] inBackground:YES]) NSBeep();
}

#pragma mark -

- (void)openSequentialWithCurrentPageInBackground:(BOOL)flag
{
	WebView *const webView = [[[NSApp mainWindow] contentView] SBP_subviewOfClass:[WebView class]];
	if(!webView) return NSBeep();
	WebFrame *const frame = [webView mainFrame];
	WebDataSource *dataSource = [frame dataSource];
	if(!dataSource) dataSource = [frame provisionalDataSource];
	if(![self openSequentialWithDataSource:dataSource inBackground:flag]) NSBeep();
}
- (BOOL)openSequentialWithDataSource:(WebDataSource *)dataSource
        inBackground:(BOOL)flag
{
	return [self openSequentialWithURL:[[dataSource request] URL] inBackground:flag];
}
- (BOOL)openSequentialWithURL:(NSURL *)aURL
        inBackground:(BOOL)flag
{
	if(!aURL) return NO;
	NSString *const appPath = [[NSWorkspace sharedWorkspace] absolutePathForAppBundleWithIdentifier:@"com.SequentialX.Sequential"];
	if(!appPath || ![[NSFileManager defaultManager] fileExistsAtPath:appPath isDirectory:NULL]) return NO;
	return [[NSWorkspace sharedWorkspace] openURLs:[NSArray arrayWithObject:aURL] withAppBundleIdentifier:@"com.SequentialX.Sequential" options:(flag ? NSWorkspaceLaunchWithoutActivation : kNilOptions) additionalEventParamDescriptor:nil launchIdentifiers:NULL];
}
- (id)javaScriptPreferenceForBrowserController:(id)browserController
{
	if(![browserController respondsToSelector:@selector(siteEditor)]) return nil;
	id const editor = [browserController siteEditor];
	if(![editor respondsToSelector:@selector(sitePreferencesController)]) return nil;
	id const prefController = [editor sitePreferencesController];
	if(![prefController respondsToSelector:@selector(_preferenceForKey:)]) return nil;
	return [prefController _preferenceForKey:@"JavaScriptEnabled"];
}

#pragma mark -

// These methods are moved to application classes.
- (id)initWithContentRect:(NSRect)contentRect styleMask:(NSUInteger)aStyle backing:(NSBackingStoreType)bufferingType defer:(BOOL)flag
{
	if(SBPOriginalWindowInitIMP) self = SBPOriginalWindowInitIMP(self, _cmd, contentRect, aStyle, bufferingType, flag);
	else self = [(NSWindow *)super initWithContentRect:contentRect styleMask:aStyle backing:bufferingType defer:flag];
	if([self respondsToSelector:@selector(setShowsToolbarButton:)]) [(NSWindow *)self setShowsToolbarButton:NO];
	return self;
}
- (IBAction)SBP_toggleJavaScriptEnabled:(id)sender
{
	id const sitePref = [[SBPController sharedController] javaScriptPreferenceForBrowserController:self];
	if([sitePref respondsToSelector:@selector(setBoolValue:)] && [sitePref respondsToSelector:@selector(boolValue)]) [sitePref setBoolValue:![sitePref boolValue]];
	else NSBeep();
}
- (BOOL)SBP_validateMenuItem:(NSMenuItem *)anItem
{
	SEL const action = [anItem action];
	if(@selector(SBP_toggleJavaScriptEnabled:) == action) {
		NSBundle *const bundle = [NSBundle bundleForClass:[SBPController class]];
		id const sitePref = [[SBPController sharedController] javaScriptPreferenceForBrowserController:self];
		[anItem setTitle:([sitePref respondsToSelector:@selector(boolValue)] && [sitePref boolValue] ? NSLocalizedStringFromTableInBundle(@"Turn JavaScript Off", nil, bundle, nil) : NSLocalizedStringFromTableInBundle(@"Turn JavaScript On", nil, bundle, nil))];
		return [self respondsToSelector:action];
	}
	return SBPOriginalValidateMenuItemIMP ? SBPOriginalValidateMenuItemIMP(self, _cmd, anItem) : [self respondsToSelector:action];
}
- (void)setLinkHoverText:(NSString *)aString
{
	if([self respondsToSelector:@selector(setWindowTitle:)] && [self respondsToSelector:@selector(documentTitle)] && [self respondsToSelector:@selector(statusBarVisible)] && ![self statusBarVisible]) [self setWindowTitle:(aString ? aString : [self documentTitle])];
	if(SBPOriginalSetLinkHoverTextIMP) SBPOriginalSetLinkHoverTextIMP(self, _cmd, aString);
}
- (NSArray *)webView:(WebView *)sender
             contextMenuItemsForElement:(NSDictionary *)element
             defaultMenuItems:(NSArray *)defaultMenuItems
{
	NSMutableArray *const items = [[(SBPOriginalContextMenuIMP ? SBPOriginalContextMenuIMP(self, _cmd, sender, element, defaultMenuItems) : defaultMenuItems) mutableCopy] autorelease];
	NSURL *const imageURL = [element objectForKey:WebElementImageURLKey];
	NSBundle *const bundle = [NSBundle bundleForClass:[SBPController class]];
	if(imageURL) {
		NSMenuItem *const item = [SBPController _menuItemWithTitle:NSLocalizedStringFromTableInBundle(@"Open Image with Sequential", nil, bundle, nil) representedObject:imageURL action:@selector(viewLinkInSequentialInForeground:)];
		NSMenu *const submenu = [[[NSMenu alloc] init] autorelease];
		[item setSubmenu:submenu];
		[items insertObject:item atIndex:0];
		[items insertObject:[NSMenuItem separatorItem] atIndex:1];

		[submenu addItem:[SBPController _menuItemWithTitle:NSLocalizedStringFromTableInBundle(@"in Foreground", nil, bundle, nil) representedObject:imageURL action:@selector(viewLinkInSequentialInForeground:)]];
		[submenu addItem:[SBPController _menuItemWithTitle:NSLocalizedStringFromTableInBundle(@"in Background", nil, bundle, nil) representedObject:imageURL action:@selector(viewLinkInSequentialInBackground:)]];
	}
	NSURL *const linkURL = [element objectForKey:WebElementLinkURLKey];
	if(linkURL) {
		NSMenuItem *const item = [SBPController _menuItemWithTitle:NSLocalizedStringFromTableInBundle(@"Open Link with Sequential", nil, bundle, nil) representedObject:linkURL action:@selector(viewLinkInSequentialInForeground:)];
		NSMenu *const submenu = [[[NSMenu alloc] init] autorelease];
		[item setSubmenu:submenu];
		[items insertObject:item atIndex:0];
		if(!imageURL) [items insertObject:[NSMenuItem separatorItem] atIndex:1];

		[submenu addItem:[SBPController _menuItemWithTitle:NSLocalizedStringFromTableInBundle(@"in Foreground", nil, bundle, nil) representedObject:linkURL action:@selector(viewLinkInSequentialInForeground:)]];
		[submenu addItem:[SBPController _menuItemWithTitle:NSLocalizedStringFromTableInBundle(@"in Background", nil, bundle, nil) representedObject:linkURL action:@selector(viewLinkInSequentialInBackground:)]];
	}
	return items;
}

#pragma mark NSMenuValidation Protocol

- (BOOL)validateMenuItem:(NSMenuItem *)anItem
{
	SEL const action = [anItem action];
	if(@selector(viewCurrentPageInSequentialInForeground:) == action || @selector(viewCurrentPageInSequentialInBackground:) == action) return !![[[NSApp mainWindow] contentView] SBP_subviewOfClass:[WebView class]];
	return [self respondsToSelector:action];
}

@end
