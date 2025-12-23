//
//  ContentView.swift
//  Lifestyle OS
//
//  Created by Le Ngo My Duyen on 23.12.25.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    
    var body: some View {
        Group {
            if authViewModel.isAuthenticated {
                MainTabView()
            } else {
                LoginView()
            }
        }
    }
}

struct MainTabView: View {
    var body: some View {
        TabView {
            InventoryListView()
                .tabItem {
                    Label("Inventory", systemImage: "square.stack.3d.up.fill")
                }
            
            ShoppingListsView()
                .tabItem {
                    Label("Shopping", systemImage: "cart.fill")
                }
            
            ExpenseListView()
                .tabItem {
                    Label("Expenses", systemImage: "dollarsign.circle.fill")
                }
            
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
        }
    }
}

struct SettingsView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    
    var body: some View {
        NavigationView {
            List {
                Section("Account") {
                    if let email = authViewModel.currentUser?.email {
                        Text("Email: \(email)")
                    }
                }
                
                Section {
                    Button("Sign Out", role: .destructive) {
                        Task {
                            await authViewModel.signOut()
                        }
                    }
                }
            }
            .navigationTitle("Settings")
        }
    }
}
