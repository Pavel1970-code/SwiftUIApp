//
//  SwiftUI_AppApp.swift
//  SwiftUI App
//
//  Created by Pavel Gutnik on 27.03.26.
//

import SwiftUI
#if canImport(FirebaseCore)
import FirebaseCore
#endif

@main
@MainActor
struct SwiftUI_AppApp: App {
    private let persistenceController = PersistenceController.shared
    
    init() {
        #if canImport(FirebaseCore)
        FirebaseApp.configure()
        #endif
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
