//
//  ChatController.m
//  ChatGPTiger
//
//  Created by Colton Booth
//  Copyright 2023 Booth Software Inc. All rights reserved. Released under Apache 2 Licence.
//

#import "UserTextField.h"

@implementation UserTextField

- (id<UserTextFieldDelegate>)delegate {
    return delegate;
}

- (void)setDelegate:(id<UserTextFieldDelegate>)newDelegate {
    delegate = newDelegate;
}


@end


