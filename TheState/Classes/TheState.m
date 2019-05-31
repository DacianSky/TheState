//
//  TheState.m
//  ThouTool
//
//  Created by thou on 6/3/16.
//  Copyright © 2016 thou. All rights reserved.
//

#import "TheState.h"

#pragma mark - tool
inline BOOL isTopic(NSString *topic,TheState *state)
{
    if (!state.topic) {
        return NO;
    }
    return [topic isEqualToString:state.topic];
}

static NSUInteger SelectorArgumentCount(SEL selector)
{
    NSUInteger argumentCount = 0;
    const char *selectorStringCursor = sel_getName(selector);
    char ch;
    
    while((ch = *selectorStringCursor)) {
        if(ch == ':') {
            ++argumentCount;
        }
        ++selectorStringCursor;
    }
    return argumentCount;
}

#pragma mark - implement
@implementation ThePreferencePersistent
@synthesize offPersistent = _offPersistent;

+ (__kindof TheState *)state:(Class)theState :(id)defaultValue :(NSString *)topic
{
    return [theState state:[[self alloc] init] :defaultValue :topic];
}

- (id)persistentValue:(id)defaultValue topic:(NSString *)topic
{
    if (self.offPersistent) {
        return defaultValue;
    }
    Class valClass = [defaultValue class];
    id existingValue = [[NSUserDefaults standardUserDefaults] objectForKey:topic];
    id decode = [NSKeyedUnarchiver unarchiveObjectWithData:existingValue];
    
    id value = defaultValue;
    if ([existingValue isKindOfClass:valClass]) {
        value = existingValue;
    }else if ([decode isKindOfClass:valClass]){
        value = decode;
    }
    return value;
}

- (void)persistent:(NSString *)topic state:(id)val
{
    if (self.offPersistent) {
        return;
    }
    if (!val) {
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:topic];
    }else if ([val conformsToProtocol:@protocol(NSCoding)]) {
        NSData *data = [NSKeyedArchiver archivedDataWithRootObject:val];
        [[NSUserDefaults standardUserDefaults] setObject:data forKey:topic];
    }else{
        [[NSUserDefaults standardUserDefaults] setObject:val forKey:topic];
    }
    [[NSUserDefaults standardUserDefaults] synchronize];
}

@end



#pragma mark - state
@interface TheState<__covariant Type>()
@property (nonatomic) dispatch_queue_t lockQueue;
//@property (nonatomic, strong,readonly) Class valClass = [self.value class];
@end
@implementation TheState

+ (TheState *)state:(id<ThePersistentProtocol>)persistentObject :(id)defaultValue :(NSString *)topic
{
    id value = [persistentObject persistentValue:defaultValue topic:topic];
    TheState *state = [[self alloc] init:value :topic];
    state.persistentObject = persistentObject;
    return state;
}

- (instancetype)init:(id)defaultValue :(NSString *)topic
{
    if (self = [super init]) {
        _lockQueue = dispatch_queue_create([[NSString stringWithFormat:@"TheState.%@",topic] UTF8String],DISPATCH_QUEUE_SERIAL);
        _topic = topic;
        _value = defaultValue;
    }
    return self;
}

- (void)willModify:(id)value to:(id)newValue
{
    if (![self needFilter:newValue value:value]) {
//        NSLog(@"willModify topic %@ with %@.",self.topic,value);
    }
}

- (void)modify:(id)newValue
{
    __weak typeof(self) state = self;
    dispatch_barrier_async(self.lockQueue, ^{
        state.value = newValue;
    });
}

- (void)didModify:(id)value to:(id)newValue
{
    [self.persistentObject persistent:self.topic state:newValue];
    if (![self needFilter:newValue value:value]) {
//        NSLog(@"didModify topic %@ with %@.",self.topic,newValue);
    }
}

- (void)setValue:(id)newValue
{
    id oldValue = _value;
    [self willModify:oldValue to:newValue];
    _value = newValue;
    [self didModify:oldValue to:newValue];
}

- (id)value
{
    return _value;
}

- (BOOL)needFilter:(id)newValue value:(id)value
{
    BOOL flag = NO;
    if (self.filterSameValue) {
        if (newValue == _value || [newValue isEqual:_value]) {
            flag = YES;
        }
    }
    return flag;
}

@end


@interface TheMonitoredState()
@property (nonatomic, strong) NSHashTable<id> *listeners;
@property (nonatomic) dispatch_queue_t listenerLockQueue;
@property (nonatomic, strong) id lastValue;
@end
@implementation TheMonitoredState

- (instancetype)init:(id)defaultValue :(NSString *)topic
{
    _listeners = [NSHashTable weakObjectsHashTable];
    _listenerLockQueue = dispatch_queue_create([[NSString stringWithFormat:@"TheState.listeners.%@",topic] UTF8String],DISPATCH_QUEUE_CONCURRENT);
    return [super init:defaultValue :topic];
}

- (void)attach:(id<TheStateListener>)listener
{
    __weak typeof(self) state = self;
    dispatch_barrier_sync(self.listenerLockQueue, ^{
        [state.listeners addObject:listener];
    });
}

- (void)willModify:(id)value to:(id)newValue{}
- (void)didModify:(id)value to:(id)newValue
{
    [super didModify:value to:newValue];
    
    __weak typeof(self) state = self;
    state.lastValue = value;
    if (![self needFilter:state.lastValue value:newValue]) {
        NSArray<id<TheStateListener>> *allListeners = [self allListeners];
        for (id<TheStateListener> l in allListeners) {
            dispatch_queue_t queue = dispatch_get_main_queue();
            if ([l respondsToSelector:@selector(stateListenerQueue)]) {
                queue = l.stateListenerQueue;
            }
            dispatch_barrier_sync(queue, ^{
                [l stateModified:state value:newValue];
            });
        }
    }
}

- (NSArray<id<TheStateListener>> *)allListeners
{
    return [self.listeners allObjects];
}

@end


@implementation TheAction

+ (instancetype)action:(id)data type:(NSString *)type
{
    return [[self alloc] init:data type:type];
}

- (instancetype)init:(id)data type:(NSString *)type
{
    _type = type;
    _data = data;
    return [super init];
}

@end


@interface TheReducer()
@property (nonatomic, strong) NSMutableArray *actions;
@end
@implementation TheReducer

- (NSMutableArray *)actions
{
    if (!_actions) {
        _actions = [[NSMutableArray alloc] init];
    }
    return _actions;
}

- (void)addTarget:(id)target action:(SEL)action
{
    if (!target || !action) {
        return;
    }
    __weak typeof(target) weak_target = target;
    [self.actions addObject:@{NSStringFromSelector(action):weak_target}];
}

- (void)dispatch:(TheAction *)action
{
    id value = self.value;
    NSArray *actions = [self.actions copy];
    for (NSDictionary *ta in actions) {
        SEL sel = NSSelectorFromString(ta.allKeys.firstObject);
        id target = ta.allValues.firstObject;
        if (!target) {
            [self.actions removeObject:ta];
            continue;
        }
        NSInteger argCount = SelectorArgumentCount(sel);
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        if (argCount==2) {
            value = [target performSelector:sel withObject:action withObject:value];
        }else if(argCount==1){
            value = [target performSelector:sel withObject:action];
        }else{
            value = [target performSelector:sel];
        }
        if (action.preventDispatch) {
            return [action setPreventDispatch:NO];
        }
#pragma clang diagnostic pop
    }
    [self modify:value];
}

@end
