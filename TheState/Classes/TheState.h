//
//  TheState.h
//  ThouTool
//
//  Created by thou on 6/3/16.
//  Copyright © 2016 thou. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN
@class TheState;
@class TheAction;

#pragma mark - tool
BOOL isTopic(NSString *topic,TheState *state);

#pragma mark - protocol
@protocol ThePersistentProtocol <NSObject>

@property (nonatomic, assign) BOOL offPersistent;

- (id)persistentValue:(id)defaultValue topic:(NSString *)topic;
- (void)persistent:(NSString *)topic state:(id)val;

@end

@protocol TheStateListener <NSObject>
@optional
- (void)stateModified:(TheState *)state value:(id)value;
- (dispatch_queue_t)stateListenerQueue;
@end

@protocol TheReducerStateListener <TheStateListener>
@optional
- (void)willReduceAction:(TheAction *)action value:(id)value;
- (void)didReduceAction:(TheAction *)action value:(id)value;
@end



#pragma mark - implement
@interface ThePreferencePersistent<__covariant Type>: NSObject<ThePersistentProtocol>
+ (__kindof TheState *)state:(Class)theState :(id)defaultValue :(NSString *)topic;
@end



#pragma mark - state
@interface TheState<__covariant Type> : NSObject
{
@private
    Type _value;
}
@property (nonatomic, copy ,readonly) NSString *topic;
@property (nonatomic, strong ,readonly) Type value;

@property (nonatomic, assign) BOOL filterSameValue;
@property (nonatomic, strong) id<ThePersistentProtocol> persistentObject;

- (instancetype)init:(Type)defaultValue :(NSString *)topic;

- (void)willModify:(Type)value to:(Type)newValue;
- (void)modify:(Type)type;
- (void)didModify:(Type)value to:(Type)newValue;

@end


@interface TheMonitoredState<__covariant Type> : TheState<NSObject>
- (void)attach:(id<TheStateListener>)listener;
@end


@interface TheAction<__covariant Type> : NSObject
+ (instancetype)action:(Type)data type:(NSString *)type;
- (instancetype)init:(Type)data type:(NSString *)type;
@property (nonatomic, copy) NSString *type;
@property (nonatomic, strong) Type data;
@property (nonatomic, assign) BOOL preventDispatch;
@property (nonatomic, assign) BOOL executeLast;
@property (nonatomic, assign) BOOL executeImmediately;
@end
@interface TheReducer : TheMonitoredState
@property (nonatomic, assign) NSInteger tpi;
- (void)addTarget:(id)target action:(SEL)action;
- (void)dispatch:(TheAction *)action;
@end

NS_ASSUME_NONNULL_END
