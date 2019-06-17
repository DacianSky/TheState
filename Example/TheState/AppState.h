//
//  AppState.h
//  ThouTool
//
//  Created by thou on 6/3/16.
//  Copyright © 2016 thou. All rights reserved.
//

#import "TheState.h"
#import "ConstDefine.h"

NS_ASSUME_NONNULL_BEGIN

#define kAppState [AppState sharedState]
#define kReservationReducer kAppState.reservationReducer
void dispatchStore(TheReducer *reducer,id data,NSString *type);
void dispatchStoreReservation(id data,NSString *type);

// action
exportNSStringUnique(kActionTypeReservationClear);
exportNSStringUnique(kActionTypeReservationInit);
exportNSStringUnique(kActionTypeReservationUpdate);

// topic
exportNSStringUnique(kTopicTypeReservation);

@interface AppState : NSObject

+ (instancetype)sharedState;

@property (nonatomic, strong) TheReducer *reservationReducer;

@end

NS_ASSUME_NONNULL_END
