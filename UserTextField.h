//
//  ChatController.m
//  ChatGPTiger
//
//  Created by Colton Booth
//  Copyright 2023 Booth Software Inc. All rights reserved. Released under Apache 2 Licence.
//

#import <Cocoa/Cocoa.h>

@protocol UserTextFieldDelegate
- (void)sendMessage:(id)sender;
@end

@interface UserTextField : NSTextField {
    id<UserTextFieldDelegate> delegate;
}
- (id<UserTextFieldDelegate>)delegate;
- (void)setDelegate:(id<UserTextFieldDelegate>)newDelegate;
@end

