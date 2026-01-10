//
//  Lifestyle_OSApp.swift
//  Lifestyle OS
//
//  Created by Le Ngo My Duyen on 23.12.25.
//
import SwiftUI
internal import Auth
import FirebaseCore

class AppDelegate: NSObject, UIApplicationDelegate {
  func application(_ application: UIApplication,
                   didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
    FirebaseApp.configure()

    return true
  }
}

// MARK: - Main App
@main
struct SupabaseAuthApp: App {
    // register app delegate for Firebase setup
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate

    @StateObject private var authViewModel = AuthViewModel()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authViewModel)
        }
    }
}

// MARK: - Content View
struct ContentView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    
    var body: some View {
        Group {
            if authViewModel.isAuthenticated {
                MainTabView().environmentObject(authViewModel)
            } else {
                LoginView()
            }
        }
    }
}

// MARK: - Home View
struct HomeView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Image(systemName: "checkmark.circle.fill")
                    .resizable()
                    .frame(width: 80, height: 80)
                    .foregroundColor(.green)
                
                Text("Welcome!")
                    .font(.title)
                    .fontWeight(.bold)
                
                if let user = authViewModel.currentUser {
                    VStack(spacing: 10) {
                        Text("You're signed in as:")
                            .foregroundColor(.secondary)
                        
                        Text(user.email ?? "Unknown")
                            .font(.headline)
                        
                        Text("User ID: \(user.id.uuidString)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(10)
                    .padding(.horizontal)
                }
                
                Button(action: {
                    Task {
                        await authViewModel.signOut()
                    }
                }) {
                    if authViewModel.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .frame(maxWidth: .infinity)
                            .padding()
                    } else {
                        Text("Sign Out")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding()
                    }
                }
                .background(Color.red)
                .foregroundColor(.white)
                .cornerRadius(10)
                .padding(.horizontal)
                .padding(.top, 20)
                
                Spacer()
            }
            .navigationTitle("Home")
        }
    }
}

// MARK: - Preview
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(AuthViewModel())
    }
}

struct MainTabView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    
    var body: some View {
        TabView {
            ExpenseListView().environmentObject(authViewModel)
                .tabItem {
                    Label("Expenses", systemImage: "dollarsign.circle.fill")
                }
            
            ShoppingListsView().environmentObject(authViewModel)
                .tabItem {
                    Label("Shopping", systemImage: "cart.fill")
                }
            
            InventoryListView().environmentObject(authViewModel)
                .tabItem {
                    Label("Inventory", systemImage: "square.stack.3d.up.fill")
                }
            
            ReceiptScannerView()
                .tabItem {
                    Label("Scan Receipt", systemImage: "doc.text.viewfinder")
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

