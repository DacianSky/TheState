//
//  AppState.m
//  ThouTool
//
//  Created by thou on 6/3/16.
//  Copyright © 2016 thou. All rights reserved.
//

#import "ConstExport.h"
#import "AppState.h"

inline void dispatchStore(TheReducer *reducer,id data,NSString *type)
{
    if (!data || !type) {
        return;
    }
    [reducer dispatch:[TheAction action:data type:type]];
}

inline void dispatchStoreReservation(id data,NSString *type)
{
    dispatchStore(kReservationReducer, data, type);
}

@implementation AppState

+ (instancetype)sharedState
{
    static AppState *store;
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        store = [[self alloc] init];
    });
    return store;
}

- (instancetype)init
{
    if (self = [super init]) {
        _reservationReducer = [ThePreferencePersistent state:TheReducer.class :[@{} mutableCopy] :kTopicTypeReservation];
        _reservationReducer.filterSameValue = YES;
        _reservationReducer.persistentObject.offPersistent = YES;
        [_reservationReducer addTarget:self action:@selector(reservation:movie:)];
    }
    return self;
}

- (NSDictionary *)reservation:(TheAction *)action movie:(NSDictionary *)value
{
    NSDictionary *data = action.data;
    NSMutableDictionary *newValue = [value mutableCopy];
    if ([action.type isEqualToString:kActionTypeReservationClear]) {
        [newValue removeAllObjects];
    }else if ([action.type isEqualToString:kActionTypeReservationInit]) {
        NSString *movie_id = [data.allKeys firstObject];
        if (![@"" isEqualToString:movie_id] && ![value.allKeys containsObject:movie_id]) {
            newValue[movie_id] = data[movie_id];
        }
    }else if ([action.type isEqualToString:kActionTypeReservationUpdate]) {
        NSString *movie_id = [data.allKeys firstObject];
        if (![@"" isEqualToString:movie_id]) {
            newValue[movie_id] = data[movie_id];
        }
    }
    
    return newValue;
}

@end
