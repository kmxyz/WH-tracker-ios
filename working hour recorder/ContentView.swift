//
//  ContentView.swift
//  working hour recorder
//
//  Created by Yun zhong Xiao on 1/31/25.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        MainTabView()
    }
}

struct MainTabView: View {
    @StateObject private var workSessionStore = WorkSessionStore()
    
    var body: some View {
        TabView {
            HomeView(workSessionStore: workSessionStore)
                .tabItem {
                    Label("Record", systemImage: "clock.badge.checkmark")
                }
            
            HistoryView(store: workSessionStore)
                .tabItem {
                    Label("History", systemImage: "clock.arrow.circlepath")
                }
            
            SummaryView(store: workSessionStore)
                .tabItem {
                    Label("Summary", systemImage: "chart.bar")
                }
        }
    }
}

#Preview {
    ContentView()
} 
