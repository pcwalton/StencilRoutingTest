//
//  DisplayListItem.m
//  StencilRoutingTest
//
//  Created by Patrick Walton on 6/21/16.
//  Copyright © 2016 Mozilla Corporation. All rights reserved.
//

#import "DisplayListItem.h"

@implementation DisplayListItem

+ (DisplayListItem *)displayListItemWithBounds:(NSRect)bounds
                                          type:(NSString *)type
                                   description:(NSString *)description {
    DisplayListItem *result = [[DisplayListItem alloc] init];
    result->_bounds = bounds;
    result->_itemType = type;
    result->_itemDescription = description;
    return result;
}

@end
