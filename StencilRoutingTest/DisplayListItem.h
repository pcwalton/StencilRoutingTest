//
//  DisplayListItem.h
//  StencilRoutingTest
//
//  Created by Patrick Walton on 6/21/16.
//  Copyright © 2016 Mozilla Corporation. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface DisplayListItem : NSObject

@property NSRect bounds;
@property NSString *itemType;
@property NSString *itemDescription;

+ (DisplayListItem *)displayListItemWithBounds:(NSRect)bounds
                                          type:(NSString *)type
                                   description:(NSString *)description;

@end
