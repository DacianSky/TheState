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
@property (nonatomic, strong ,readwrite) Type value;
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

- (void)willModify:(id)value to:(id)newValue{}

- (void)modify:(id<NSCopying>)newValue
{
    __weak typeof(self) state = self;
    dispatch_barrier_async(self.lockQueue, ^{
        __strong typeof(state) self = state;
        id oldValue = self.value;
        [self willModify:oldValue to:newValue];
        self.value = newValue;
        [self didModify:oldValue to:newValue];
    });
}

- (void)didModify:(id)value to:(id)newValue
{
    [self.persistentObject persistent:self.topic state:newValue];
}

@end


@interface TheMonitoredState()
@property (nonatomic, strong) NSHashTable<id> *listeners;
@end
@implementation TheMonitoredState

- (instancetype)init:(id)defaultValue :(NSString *)topic
{
    _listeners = [NSHashTable weakObjectsHashTable];
    return [super init:defaultValue :topic];
}

- (void)attach:(id<TheStateListener>)listener
{
    __weak typeof(self) state = self;
    [state.listeners addObject:listener];
}

- (void)modify:(id<NSCopying>)newValue
{
    __weak typeof(self) state = self;
    dispatch_barrier_async(self.lockQueue, ^{
        __strong typeof(state) self = state;
        id oldValue = self.value;
        [self willModify:oldValue to:newValue];
        self.value = newValue;
        [self assignListener:oldValue to:newValue];
        [self didModify:newValue to:newValue];
    });
}

- (void)assignListener:(id)value to:(id)newValue
{
    __weak typeof(self) state = self;
    NSArray<id<TheStateListener>> *allListeners = [self allListeners];
    for (id<TheStateListener> l in allListeners) {
        dispatch_queue_t queue = dispatch_get_main_queue();
        if ([l respondsToSelector:@selector(stateListenerQueue)]) {
            queue = l.stateListenerQueue;
        }
        dispatch_sync(queue, ^{
            if ([l respondsToSelector:@selector(stateModified:value:)]) {
                [l stateModified:state value:newValue];
            }
        });
    }
}

- (NSArray<__kindof id<TheStateListener>> *)allListeners
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
@property (nonatomic) dispatch_queue_t reducerQueue;
@property (nonatomic, strong) NSRecursiveLock *coreLock;

@property (nonatomic, assign) BOOL uncompleteDispatch;
@property (nonatomic, strong) NSMutableArray *aggregate;
@end
@implementation TheReducer

- (instancetype)init:(id)defaultValue :(NSString *)topic
{
    _tpi = 20;
//    _reducerQueue = dispatch_queue_create([[NSString stringWithFormat:@"TheState.reducer.%@",topic] UTF8String],DISPATCH_QUEUE_SERIAL);
    _reducerQueue = dispatch_queue_create([[NSString stringWithFormat:@"TheState.reducer.%@",topic] UTF8String],DISPATCH_QUEUE_CONCURRENT);
    return [super init:defaultValue :topic];
}

- (NSMutableArray *)aggregate
{
    if (!_aggregate) {
        _aggregate = [[NSMutableArray alloc] init];
    }
    return _aggregate;
}

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
    if (![action isKindOfClass:[TheAction class]]) {
        return;
    }
    __weak typeof(self) state = self;
    dispatch_async(self.reducerQueue, ^{
        __strong typeof(state) self = state;
        [self lock];
        [self.aggregate addObject:action];
        [self unlock];
    });
    dispatch_async(self.reducerQueue, ^{
        __strong typeof(state) self = state;
        [self executeNext];
    });
}

- (void)executeNext
{
    if (self.uncompleteDispatch || self.aggregate.count<=0) {
        return;
    }
    [self lock];
    self.uncompleteDispatch = YES;
    id value = self.value;
    int t = 0;
    while (self.aggregate.count>0) {
        TheAction *action = [self.aggregate firstObject];
        if (!action || action.executeLast) {
            break;
        }
        value = [self executeAction:action withValue:value];
        [self lock];
        [self.aggregate removeObject:action];
        [self unlock];
        if (action.executeImmediately) {
            break;
        }
        t++;
        if (t>=self.tpi) {
            break;
        }
    }
    [self unlock];
    [self modify:value];
}

- (id)executeAction:(TheAction *)action withValue:(id)nValue
{
    id value = [nValue mutableCopy];
    [self willExecuteAction:action withValue:value];
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
            action.preventDispatch = NO;
            value = nValue;
            break;
        }
#pragma clang diagnostic pop
    }
    [self didExecuteAction:action withValue:value];
    return value;
}

- (void)didModify:(id)value to:(id)newValue
{
    [super didModify:value to:newValue];
    [self lock];
    self.uncompleteDispatch = NO;
    [self unlock];
    [self executeNext];
}

- (void)willExecuteAction:(TheAction *)action withValue:(id)nValue
{
    NSArray<id<TheReducerStateListener>> *allListeners = [self allListeners];
    for (id<TheReducerStateListener> l in allListeners) {
        dispatch_queue_t queue = dispatch_get_main_queue();
        if ([l respondsToSelector:@selector(stateListenerQueue)]) {
            queue = l.stateListenerQueue;
        }
        dispatch_sync(queue, ^{
            if ([l respondsToSelector:@selector(willReduceAction:value:)]) {
                [l willReduceAction:action value:nValue];
            }
        });
    }
}

- (void)didExecuteAction:(TheAction *)action withValue:(id)value
{
    NSArray<id<TheReducerStateListener>> *allListeners = [self allListeners];
    for (id<TheReducerStateListener> l in allListeners) {
        dispatch_queue_t queue = dispatch_get_main_queue();
        if ([l respondsToSelector:@selector(stateListenerQueue)]) {
            queue = l.stateListenerQueue;
        }
        dispatch_sync(queue, ^{
            if ([l respondsToSelector:@selector(didReduceAction:value:)]) {
                [l didReduceAction:action value:value];
            }
        });
    }
}

#pragma mark - NSLocking

- (void)lock
{
    if (!self.coreLock) {
        self.coreLock = [[NSRecursiveLock alloc] init];
    }
    [self.coreLock lock];
}

- (void)unlock
{
    [self.coreLock unlock];
}

@end
