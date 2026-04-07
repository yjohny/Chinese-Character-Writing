import Foundation
import SwiftData

/// Versioned schema baseline for the app's persistence layer.
///
/// Wrapping models in a `VersionedSchema` enables future migrations via
/// `ChineseWritingMigrationPlan`. To introduce a schema change:
///
/// 1. Create a new `SchemaV2` enum that captures the *new* model shapes
///    (typically by namespacing copies of the model classes inside the enum).
/// 2. Add `SchemaV2.self` to `ChineseWritingMigrationPlan.schemas`.
/// 3. Add a `MigrationStage` (`.lightweight` for additive changes, `.custom`
///    for renames / type changes / data transforms) to `stages`.
/// 4. Update `ChineseWritingApp` to instantiate the container against the
///    latest schema version.
enum SchemaV1: VersionedSchema {
    static var versionIdentifier: Schema.Version = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] {
        [ReviewCard.self, ReviewLog.self, UserProfile.self]
    }
}

/// Migration plan for the app. Currently has only V1 with no stages; future
/// schema versions append themselves here.
enum ChineseWritingMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [SchemaV1.self]
    }

    static var stages: [MigrationStage] {
        []
    }
}
