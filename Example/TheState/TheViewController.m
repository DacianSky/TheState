//
//  TheViewController.m
//  TheState
//
//  Created by sdqvsqiu@gmail.com on 05/24/2019.
//  Copyright (c) 2019 sdqvsqiu@gmail.com. All rights reserved.
//

#import "TheViewController.h"
#import "AppState.h"

@interface TheViewController ()<TheStateListener>

@end

@implementation TheViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    [kReservationReducer attach:self];
    
    // 发送action改变状态
//    dispatchStoreReservation([@{} mutableCopy],kActionTypeReservationClear);
    dispatchStoreReservation(@{@"prevue_id_1":@(YES)},kActionTypeReservationInit);
    dispatchStoreReservation(@{@"prevue_id_1":@(NO)},kActionTypeReservationUpdate);
    dispatchStoreReservation(@{@"prevue_id_2":@(NO)},kActionTypeReservationUpdate);
    dispatchStoreReservation(@{@"prevue_id_2":@(YES)},kActionTypeReservationUpdate);
}

#pragma mark - TheStateListener  状态监听
//- (dispatch_queue_t)stateListenerQueue
//{
//    return dispatch_get_main_queue();
//}

- (void)stateModified:(TheState *)state value:(NSDictionary *)collectList
{
    if(isTopic(kTopicTypeReservation,state)){
        if (![@"" isEqualToString: @"prevue_id_1"]) {
            NSString *lastState = collectList[@"prevue_id_1"];
            NSLog(@"prevue_id_1 state:%@",lastState);
        }
    }
}

@end
