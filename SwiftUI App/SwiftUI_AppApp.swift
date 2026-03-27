//
//  SwiftUI_AppApp.swift
//  SwiftUI App
//
//  Created by Pavel Gutnik on 27.03.26.
//

import SwiftUI

@main
struct SwiftUI_AppApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
