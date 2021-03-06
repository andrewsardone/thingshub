//
//  CDZThingsHubConfiguration.m
//  thingshub
//
//  Created by Chris Dzombak on 1/13/14.
//  Copyright (c) 2014 Chris Dzombak. All rights reserved.
//

#import "CDZThingsHubConfiguration.h"
#import "CDZThingsHubErrorDomain.h"

static NSString * const CDZThingsHubConfigFileName = @".thingshubconfig";

static NSString * const CDZThingsHubConfigDefaultTagNamespace = @"github";
static NSString * const CDZThingsHubConfigDefaultReviewTagName = @"review";

@interface CDZThingsHubConfiguration ()

@property (nonatomic, copy, readwrite) NSString *tagNamespace;
@property (nonatomic, copy, readwrite) NSString *reviewTagName;
@property (nonatomic, copy, readwrite) NSString *githubLogin;
@property (nonatomic, copy, readwrite) NSString *githubOrgName;
@property (nonatomic, copy, readwrite) NSString *githubRepoName;
@property (nonatomic, copy, readwrite) NSString *thingsAreaName;

@end

@implementation CDZThingsHubConfiguration

+ (instancetype)currentConfigurationWithError:(NSError **)error {
    static CDZThingsHubConfiguration *currentConfig;
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        currentConfig = [[CDZThingsHubConfiguration alloc] init];
        
        NSString *homePath = NSHomeDirectory();
        NSArray *homePathComponents = [homePath pathComponents];
        NSArray *workingPathComponents = [[[NSFileManager defaultManager] currentDirectoryPath] pathComponents];
        
        if (workingPathComponents.count < [homePath pathComponents].count
            || !([[workingPathComponents subarrayWithRange:NSMakeRange(0, homePathComponents.count)] isEqualToArray:homePathComponents])) {
            CDZCLIPrint(@"This tool must be run from within your home directory: %@", homePath);
        }
        
        for (NSUInteger i = homePathComponents.count - 1; i < workingPathComponents.count; ++i) {
            NSArray *pathComponents = [workingPathComponents subarrayWithRange:NSMakeRange(0, i)];
            NSString *path = [NSString pathWithComponents:pathComponents];
            
            NSString *configFilePath = [path stringByAppendingPathComponent:CDZThingsHubConfigFileName];
            NSString *configContents = [NSString stringWithContentsOfFile:configFilePath encoding:NSUTF8StringEncoding error:NULL];
            
            if (configContents) {
                CDZCLIPrint(@"Merging config file %@", configFilePath);
                CDZThingsHubConfiguration *config = [[self class] configurationFromFileContents:configContents];
                [currentConfig mergeInPriorityConfiguration:config];
            }
        }
        
        // Finally, allow command-line args to override this:
        [currentConfig mergeInPriorityConfiguration:[self configurationFromDefaults]];
    });
    
    NSError *validationError = [currentConfig validationError];
    if (validationError) {
        if (error) {
            *error = validationError;
        }
        return nil;
    }
    
    return currentConfig;
}

/**
 Parses the given file contents into a configuration object. The resulting object is not guaranteed to be valid.
 
 File format is "key = value" pairs. Whitespace before and after each key/value is ignored. Lines beginning (at index 0) with '#' are ignored as comments. Empty lines are ignored.
 */
+ (instancetype)configurationFromFileContents:(NSString *)fileContents {
    CDZThingsHubConfiguration *config = [[CDZThingsHubConfiguration alloc] init];
    
    for (NSString *line in [fileContents componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]]) {
        NSString *trimmedLine = [line stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        if ([trimmedLine isEqualToString:@""]) continue;
        
        if ([trimmedLine characterAtIndex:0] == '#') continue;
        
        NSArray *lineComponents = [trimmedLine componentsSeparatedByString:@"="];
        if (lineComponents.count != 2) {
            CDZCLIPrint(@"Warning: invalid configuration line (too many components): \"%@\"", line);
            continue;
        }
        
        NSString *configKey = [lineComponents[0] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        NSString *propertyKey = [[self class] propertyKeysByConfigKey][configKey];
        
        if (!propertyKey) {
            CDZCLIPrint(@"Warning: invalid configuration line (invalid key): \"%@\"", line);
            continue;
        }
        
        NSString *value = [lineComponents[1] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        [config setValue:value forKey:propertyKey];
    }
    
    return config;
}

/// Builds a configuration object from [NSUserDefaults standardUserDefaults]
+ (instancetype)configurationFromDefaults {
    CDZThingsHubConfiguration *config = [[CDZThingsHubConfiguration alloc] init];
    
    [[self propertyKeysByConfigKey] enumerateKeysAndObjectsUsingBlock:^(NSString *configKey, NSString *propertyKey, BOOL *stop) {
        NSString *configValue = [[NSUserDefaults standardUserDefaults] stringForKey:configKey];
        if (configValue) {
            [config setValue:configValue forKeyPath:propertyKey];
        }
    }];
    
    return config;
}

/// Designated initializer
- (instancetype)init {
    self = [super init];
    if (self) {
        _tagNamespace = CDZThingsHubConfigDefaultTagNamespace;
        _reviewTagName = CDZThingsHubConfigDefaultReviewTagName;
    }
    return self;
}

#pragma mark - Merging

/// Merges in the given configuration. Values in the given config take priority.
- (void)mergeInPriorityConfiguration:(CDZThingsHubConfiguration *)priorityConfiguration {
    for (NSString *propertyKey in [[[self class] propertyKeysByConfigKey] allValues]) {
        id value = [priorityConfiguration valueForKey:propertyKey];
        if (value) {
            [self setValue:value forKey:propertyKey];
        }
    }
}

#pragma mark - Validation

/// Return an error if this object is in an invalid state; nil otherwise.
- (NSError *)validationError {
    if (!self.githubLogin) {
        return [NSError errorWithDomain:kThingsHubErrorDomain
                                   code:CDZErrorCodeConfigurationValidationError
                               userInfo:@{ NSLocalizedDescriptionKey: @"Github username must be set." }];
    }
    else if (!self.githubOrgName) {
        return [NSError errorWithDomain:kThingsHubErrorDomain
                                   code:CDZErrorCodeConfigurationValidationError
                               userInfo:@{ NSLocalizedDescriptionKey: @"Github organization must be set." }];
    }
    else if (!self.githubRepoName) {
        return [NSError errorWithDomain:kThingsHubErrorDomain
                                   code:CDZErrorCodeConfigurationValidationError
                               userInfo:@{ NSLocalizedDescriptionKey: @"Github repo name must be set." }];
    }
    
    return nil;
}

#pragma mark - NSObject Protocol

- (NSString *)description {
    return [NSString stringWithFormat:@"<%@ %p>: {\n\ttagNamespace: %@\n\treviewTagName: %@\n\tgithubLogin: %@\n\tgithubOrgName:%@\n\tgithubRepoName: %@\n\tthingsAreaName: %@\n}",
            NSStringFromClass([self class]),
            self,
            self.tagNamespace,
            self.reviewTagName,
            self.githubLogin,
            self.githubOrgName,
            self.githubRepoName,
            self.thingsAreaName
            ];
}

#pragma mark - Input Handling Help

/// Maps user-facing configuration keys to KVC property keys for CDZThingsHubCOnfiguration objects.
+ (NSDictionary *)propertyKeysByConfigKey {
    static NSDictionary *propertyKeysByConfigKey;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        propertyKeysByConfigKey = @{
                                    @"tagNamespace": NSStringFromSelector(@selector(tagNamespace)),
                                    @"reviewTag": NSStringFromSelector(@selector(reviewTagName)),
                                    @"githubLogin": NSStringFromSelector(@selector(githubLogin)),
                                    @"githubOrg": NSStringFromSelector(@selector(githubOrgName)),
                                    @"githubRepo": NSStringFromSelector(@selector(githubRepoName)),
                                    @"thingsArea": NSStringFromSelector(@selector(thingsAreaName)),
                                    };
    });
    return propertyKeysByConfigKey;
}

@end
