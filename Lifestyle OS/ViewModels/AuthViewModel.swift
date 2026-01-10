//
//  AuthViewModel.swift
//  Lifestyle OS
//
//  Created by Le Ngo My Duyen on 23.12.25.
//

import Foundation
import Supabase
import Combine

@MainActor
class AuthViewModel: ObservableObject {
    @Published var isAuthenticated = false
    @Published var currentUser: User?
    @Published var currentAccountId: UUID?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let authService = AuthService()
    
    init() {
        Task {
            await checkAuthStatus()
        }
    }
    
    func checkAuthStatus() async {
        do {
            if let user = try await authService.getCurrentUser() {
                currentUser = user
                isAuthenticated = true
                await fetchUserAccount()
            }
        } catch {
            isAuthenticated = false
        }
    }
    
    func signIn(email: String, password: String) async {
        isLoading = true
        errorMessage = nil
        
        do {
            let session = try await authService.signIn(email: email, password: password)
            currentUser = session.user
            isAuthenticated = true
            await fetchUserAccount()
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    func signUp(email: String, password: String) async {
        isLoading = true
        errorMessage = nil
        
        do {
            let user = try await authService.signUp(email: email, password: password)
            currentUser = user
            // After signup, create a default account
            await createDefaultAccount()
            isAuthenticated = true
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    func signOut() async {
        do {
            try await authService.signOut()
            isAuthenticated = false
            currentUser = nil
            currentAccountId = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    private func fetchUserAccount() async {
        guard let userId = currentUser?.id else { return }
        
        do {
            let client = SupabaseService.shared.client
            let response: [AccountUser] = try await client
                .from("account_users")
                .select()
                .eq("user_id", value: userId.uuidString)
                .limit(1)
                .execute()
                .value
            
            if let accountUser = response.first {
                currentAccountId = accountUser.accountId
            }
        } catch {
            print("Error fetching account: \(error)")
        }
    }
    
    private func createDefaultAccount() async {
        guard let userId = currentUser?.id else { return }
        
        do {
            let client = SupabaseService.shared.client
            
            // Create account directly using your model if it exists
            struct CreateAccount: Codable {
                let name: String
            }
            let accountData = CreateAccount(name: "My Kitchen")
            
            // Create account
            let account: Account = try await client
                .from("accounts")
                .insert(accountData)
                .select()
                .single()
                .execute()
                .value
            
            // Create a proper model for account_user
            struct AccountUser: Codable {
                let account_id: String
                let user_id: String
                let role: String
            }

            let accountUser = AccountUser(
                account_id: account.id.uuidString,
                user_id: userId.uuidString,
                role: "owner"
            )

            try await client
                .from("account_users")
                .insert(accountUser)
                .execute()
            
            currentAccountId = account.id
        } catch {
            print("Error creating account: \(error)")
        }
    }
}
