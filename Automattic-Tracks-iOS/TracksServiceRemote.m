#import "TracksServiceRemote.h"

@implementation TracksServiceRemote


- (void)sendSingleTracksEvent:(TracksEvent *)tracksEvent completionHandler:(void (^)(void))completion
{
    NSDictionary *dataToSend = @{@"events" : @[tracksEvent.dictionaryRepresentation],
                                 @"commonProps" : @{}};
    NSError *error = nil;
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:@"https://public-api.wordpress.com/rest/v1.1/tracks/record"]];
    request.HTTPMethod = @"POST";
    request.HTTPBody = [NSJSONSerialization dataWithJSONObject:dataToSend options:0 error:&error];
    [request addValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [request addValue:@"application/json" forHTTPHeaderField:@"Accept"];
    
    NSURLSession *sharedSession = [NSURLSession sharedSession];
    
    NSURLSessionDataTask *task;
    task = [sharedSession dataTaskWithRequest:request
                            completionHandler:^(NSData *data, NSURLResponse *response, NSError *error)
    {
        NSString *dataString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        NSLog(@"Response: %@ \n\nData: %@:", response, dataString);
        
        if (completion) {
            completion();
        }
    }];
    
    [task resume];
}


- (void)sendBatchOfEvents:(NSArray *)events withSharedProperties:(NSDictionary *)properties completionHandler:(void (^)(void))completion
{
    NSDictionary *dataToSend = @{@"events" : events,
                                 @"commonProps" : [self normalizeCommonProperties:properties]};
    NSLog(@"Data to send: \n%@", dataToSend);
    
    NSError *error = nil;
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:@"https://public-api.wordpress.com/rest/v1.1/tracks/record"]];
    request.HTTPMethod = @"POST";
    request.HTTPBody = [NSJSONSerialization dataWithJSONObject:dataToSend options:0 error:&error];
    [request addValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [request addValue:@"application/json" forHTTPHeaderField:@"Accept"];
    
    NSURLSession *sharedSession = [NSURLSession sharedSession];
    
    NSURLSessionDataTask *task;
    task = [sharedSession dataTaskWithRequest:request
                            completionHandler:^(NSData *data, NSURLResponse *response, NSError *error)
            {
                NSString *dataString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
                NSLog(@"Response: %@ \n\nData: %@:", response, dataString);
                
                if (completion) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        completion();
                    });
                }
            }];
    
    [task resume];
}


- (NSDictionary *)normalizeCommonProperties:(NSDictionary *)commonProps
{
    NSString *USER_AGENT_NAME_KEY = @"_via_ua";
    NSString *DEFAULT_USER_AGENT = @"Nosara Client for iOS 0.0.0";
    NSMutableDictionary *normalizedProps = [NSMutableDictionary dictionaryWithDictionary:commonProps];
    
    normalizedProps[USER_AGENT_NAME_KEY] = DEFAULT_USER_AGENT;
    
    return normalizedProps;
}

@end