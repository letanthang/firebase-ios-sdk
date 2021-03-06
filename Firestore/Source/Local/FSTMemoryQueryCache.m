/*
 * Copyright 2017 Google
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#import "FSTMemoryQueryCache.h"

#import "FSTQuery.h"
#import "FSTQueryData.h"
#import "FSTReferenceSet.h"
#import "FSTSnapshotVersion.h"

NS_ASSUME_NONNULL_BEGIN

@interface FSTMemoryQueryCache ()

/** Maps a query to the data about that query. */
@property(nonatomic, strong, readonly) NSMutableDictionary<FSTQuery *, FSTQueryData *> *queries;

/** A ordered bidirectional mapping between documents and the remote target IDs. */
@property(nonatomic, strong, readonly) FSTReferenceSet *references;

/** The highest numbered target ID encountered. */
@property(nonatomic, assign) FSTTargetID highestTargetID;

@end

@implementation FSTMemoryQueryCache {
  /** The last received snapshot version. */
  FSTSnapshotVersion *_lastRemoteSnapshotVersion;
}

- (instancetype)init {
  if (self = [super init]) {
    _queries = [NSMutableDictionary dictionary];
    _references = [[FSTReferenceSet alloc] init];
    _lastRemoteSnapshotVersion = [FSTSnapshotVersion noVersion];
  }
  return self;
}

#pragma mark - FSTQueryCache implementation
#pragma mark Query tracking

- (void)start {
  // Nothing to do.
}

- (void)shutdown {
  // No resources to release.
}

- (FSTTargetID)highestTargetID {
  return _highestTargetID;
}

- (FSTSnapshotVersion *)lastRemoteSnapshotVersion {
  return _lastRemoteSnapshotVersion;
}

- (void)setLastRemoteSnapshotVersion:(FSTSnapshotVersion *)snapshotVersion
                               group:(FSTWriteGroup *)group {
  _lastRemoteSnapshotVersion = snapshotVersion;
}

- (void)addQueryData:(FSTQueryData *)queryData group:(__unused FSTWriteGroup *)group {
  self.queries[queryData.query] = queryData;
  if (queryData.targetID > self.highestTargetID) {
    self.highestTargetID = queryData.targetID;
  }
}

- (void)removeQueryData:(FSTQueryData *)queryData group:(__unused FSTWriteGroup *)group {
  [self.queries removeObjectForKey:queryData.query];
  [self.references removeReferencesForID:queryData.targetID];
}

- (nullable FSTQueryData *)queryDataForQuery:(FSTQuery *)query {
  return self.queries[query];
}

#pragma mark Reference tracking

- (void)addMatchingKeys:(FSTDocumentKeySet *)keys
            forTargetID:(FSTTargetID)targetID
                  group:(__unused FSTWriteGroup *)group {
  [self.references addReferencesToKeys:keys forID:targetID];
}

- (void)removeMatchingKeys:(FSTDocumentKeySet *)keys
               forTargetID:(FSTTargetID)targetID
                     group:(__unused FSTWriteGroup *)group {
  [self.references removeReferencesToKeys:keys forID:targetID];
}

- (void)removeMatchingKeysForTargetID:(FSTTargetID)targetID group:(__unused FSTWriteGroup *)group {
  [self.references removeReferencesForID:targetID];
}

- (FSTDocumentKeySet *)matchingKeysForTargetID:(FSTTargetID)targetID {
  return [self.references referencedKeysForID:targetID];
}

#pragma mark - FSTGarbageSource implementation

- (nullable id<FSTGarbageCollector>)garbageCollector {
  return self.references.garbageCollector;
}

- (void)setGarbageCollector:(nullable id<FSTGarbageCollector>)garbageCollector {
  self.references.garbageCollector = garbageCollector;
}

- (BOOL)containsKey:(FSTDocumentKey *)key {
  return [self.references containsKey:key];
}

@end

NS_ASSUME_NONNULL_END
