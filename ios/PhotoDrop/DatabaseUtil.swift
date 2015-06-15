//
//  Database.swift
//  PhotoDrop
//
//  Created by Pasin Suriyentrakorn on 1/18/15.
//  Copyright (c) 2015 Couchbase. All rights reserved.
//

import Foundation

class DatabaseUtil {
    class func getEmptyDatabase(name: String!) throws -> CBLDatabase {
        do {
            let database = try CBLManager.sharedInstance().existingDatabaseNamed(name)
            try database.deleteDatabase()
        } catch {}
        return try CBLManager.sharedInstance().databaseNamed(name)
    }
}