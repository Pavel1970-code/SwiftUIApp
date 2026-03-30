//
//  SwiftUI_AppApp.swift
//  SwiftUI App
//
//  Created by Pavel Gutnik on 27.03.26.
//

import SwiftUI

@main
@MainActor
struct SwiftUI_AppApp: App {
    private let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
