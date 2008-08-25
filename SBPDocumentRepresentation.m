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
#import "SBPDocumentRepresentation.h"

// Classes
#import "SBPController.h"


@implementation SBPDocumentRepresentation

#pragma mark Instance Methods

- (void)undisplayInWebView:(WebView *)webView
{
	if([webView goBack]) return;
	id const UIDelegate = [webView UIDelegate];
	if([UIDelegate respondsToSelector:@selector(webViewClose:)]) [UIDelegate webViewClose:webView];
	else [[webView window] close];
}

#pragma mark WebDocumentRepresentation Protocol

- (void)setDataSource:(WebDataSource *)dataSource
{
	if([[SBPController sharedController] openSequentialWithDataSource:dataSource inBackground:NO]) [self performSelector:@selector(undisplayInWebView:) withObject:[[dataSource webFrame] webView] afterDelay:0 inModes:[NSArray arrayWithObject:(NSString *)kCFRunLoopCommonModes]];
}
- (void)receivedData:(NSData *)data withDataSource:(WebDataSource *)dataSource {}
- (void)receivedError:(NSError *)error withDataSource:(WebDataSource *)dataSource {}
- (void)finishedLoadingWithDataSource:(WebDataSource *)dataSource {}
- (BOOL)canProvideDocumentSource
{
	return NO;
}
- (NSString *)documentSource
{
	return nil;
}
- (NSString *)title
{
	return @"";
}

@end
