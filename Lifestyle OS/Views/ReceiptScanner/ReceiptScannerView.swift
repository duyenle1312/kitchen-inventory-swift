// ReceiptScannerView.swift

import SwiftUI
import PhotosUI
internal import Auth

struct ReceiptScannerView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var viewModel = ReceiptScannerViewModel()
    
    @State private var selectedImage: PhotosPickerItem?
    @State private var showCamera = false
    @State private var capturedImage: UIImage?
    
    var body: some View {
        NavigationView {
            ZStack {
                mainContent
                loadingOverlay
            }
            .navigationTitle("Scan Receipt")
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $showCamera) {
                ImagePicker(image: $capturedImage, sourceType: .camera)
            }
            .onChange(of: selectedImage) { _, newValue in
                Task {
                    if let data = try? await newValue?.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        await viewModel.scanReceipt(from: image)
                    }
                }
            }
            .onChange(of: capturedImage) { _, newImage in
                if let image = newImage {
                    Task {
                        await viewModel.scanReceipt(from: image)
                    }
                }
            }
            .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
                Button("OK") {
                    viewModel.errorMessage = nil
                }
            } message: {
                if let error = viewModel.errorMessage {
                    Text(error)
                }
            }
            .alert("Success", isPresented: $viewModel.showSuccess) {
                Button("OK") {
                    viewModel.reset()
                }
            } message: {
                Text("Expenses have been added successfully!")
            }
        }
    }
    
    @ViewBuilder
    private var mainContent: some View {
        if viewModel.scannedReceipt == nil {
            EmptyStateView(showCamera: $showCamera, selectedImage: $selectedImage)
        } else {
            ReceiptReviewView(viewModel: viewModel)
        }
    }
    
    @ViewBuilder
    private var loadingOverlay: some View {
        if viewModel.isScanning {
            LoadingOverlay(message: "Scanning receipt...")
        }
    }
}

// MARK: - Empty State View

struct EmptyStateView: View {
    @Binding var showCamera: Bool
    @Binding var selectedImage: PhotosPickerItem?
    
    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                headerSection
                actionButtons
                tipsSection
            }
            .padding()
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text.viewfinder")
                .font(.system(size: 80))
                .foregroundStyle(.blue.gradient)
                .symbolEffect(.pulse)
            
            VStack(spacing: 8) {
                Text("Scan Receipt")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("Take a photo or select an image of your receipt")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.top, 40)
    }
    
    private var actionButtons: some View {
        VStack(spacing: 12) {
            Button {
                showCamera = true
            } label: {
                Label("Take Photo", systemImage: "camera.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.blue.gradient)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            
            PhotosPicker(selection: $selectedImage, matching: .images) {
                Label("Choose from Library", systemImage: "photo.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .foregroundStyle(.blue)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }
    
    private var tipsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Tips for best results:")
                .font(.headline)
            
            TipRow(text: "Ensure receipt is flat and well-lit")
            TipRow(text: "Hold camera steady")
            TipRow(text: "Works with Bulgarian store receipts")
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct TipRow: View {
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .font(.body)
            Text(text)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Loading Overlay

struct LoadingOverlay: View {
    let message: String
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(.white)
                
                Text(message)
                    .foregroundColor(.white)
                    .font(.headline)
            }
            .padding(30)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 20))
        }
    }
}

// MARK: - Receipt Review View

struct ReceiptReviewView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @ObservedObject var viewModel: ReceiptScannerViewModel
    
    let categories = ["Food & Drink", "Home", "Rent & Utilities", "Gold/Silver", "ETFs", "Transport", "Telecom", "Crochet", "Fun", "Eating Out", "Work", "Other"]
    
    var body: some View {
        if let receipt = viewModel.scannedReceipt {
            VStack(spacing: 0) {
                receiptHeader(receipt)
                itemsList(receipt)
                actionButtons(receipt)
            }
        }
    }
    
    private func receiptHeader(_ receipt: ScannedReceipt) -> some View {
        VStack(spacing: 8) {
            if let storeName = receipt.storeName {
                Text(storeName)
                    .font(.title2)
                    .fontWeight(.bold)
            }
            
            HStack(spacing: 8) {
                Text("Total:")
                    .font(.headline)
                    .foregroundColor(.secondary)
                
                Text(formatAmount(receipt.total, currency: receipt.currency))
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(.blue.gradient)
            }
            
            Text("\(receipt.items.count) items")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemGray6))
    }
    
    private func itemsList(_ receipt: ScannedReceipt) -> some View {
        List {
            ForEach(Array(receipt.items.enumerated()), id: \.element.id) { index, item in
                ReceiptItemRow(
                    item: item,
                    index: index,
                    categories: categories,
                    onUpdate: { name, amount, category in
                        viewModel.updateItem(at: index, name: name, amount: amount, category: category)
                    },
                    onDelete: {
                        viewModel.removeItem(at: index)
                    }
                )
            }
        }
        .listStyle(.plain)
    }
    
    private func actionButtons(_ receipt: ScannedReceipt) -> some View {
        VStack(spacing: 12) {
            Button {
                saveExpenses()
            } label: {
                if viewModel.isSaving {
                    ProgressView()
                        .tint(.white)
                } else {
                    Label("Add to Expenses", systemImage: "plus.circle.fill")
                        .fontWeight(.semibold)
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(receipt.items.isEmpty ? Color.gray : .blue)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .disabled(viewModel.isSaving || receipt.items.isEmpty)
            
            Button {
                viewModel.reset()
            } label: {
                Text("Scan Another Receipt")
                    .foregroundStyle(.blue)
            }
        }
        .padding()
        .background(Color(.systemBackground))
    }
    
    private func saveExpenses() {
        guard let user = authViewModel.currentUser else {
            print("❌ No current user")
            return
        }
        
        Task {
            await viewModel.saveToExpenses(accountId: user.id)
        }
    }
    
    private func formatAmount(_ amount: Decimal, currency: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        return formatter.string(from: amount as NSDecimalNumber) ?? "\(currency) 0.00"
    }
}

// MARK: - Receipt Item Row

struct ReceiptItemRow: View {
    let item: ReceiptItem
    let index: Int
    let categories: [String]
    let onUpdate: (String?, String?, String?) -> Void
    let onDelete: () -> Void
    
    @State private var isEditing = false
    @State private var editedName: String
    @State private var editedAmount: String
    @State private var selectedCategory: String
    
    init(item: ReceiptItem, index: Int, categories: [String], onUpdate: @escaping (String?, String?, String?) -> Void, onDelete: @escaping () -> Void) {
        self.item = item
        self.index = index
        self.categories = categories
        self.onUpdate = onUpdate
        self.onDelete = onDelete
        
        _editedName = State(initialValue: item.translatedName ?? item.displayName)
        _editedAmount = State(initialValue: String(describing: item.amount))
        _selectedCategory = State(initialValue: item.category ?? "Food & Drink")
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            itemHeader
            itemDetails
        }
        .padding(.vertical, 8)
    }
    
    private var itemHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                if isEditing {
                    TextField("Item name", text: $editedName)
                        .textFieldStyle(.roundedBorder)
                        .onAppear {
                            editedName = item.translatedName ?? item.displayName
                        }
                } else {
                    Text(item.displayName)
                        .font(.headline)
                    
                    if item.name != item.displayName {
                        Text(item.name)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer()
            
            if isEditing {
                TextField("Amount", text: $editedAmount)
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.decimalPad)
                    .frame(width: 90)
            } else {
                Text(formatAmount(item.amount))
                    .font(.headline)
                    .foregroundStyle(.blue.gradient)
            }
        }
    }
    
    @ViewBuilder
    private var itemDetails: some View {
        if isEditing {
            editingControls
        } else {
            viewControls
        }
    }
    
    private var editingControls: some View {
        HStack {
            Picker("Category", selection: $selectedCategory) {
                ForEach(categories, id: \.self) { category in
                    Text(category).tag(category)
                }
            }
            .pickerStyle(.menu)
            .tint(.blue)
            
            Spacer()
            
            Button("Save") {
                saveChanges()
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
            .controlSize(.small)
            
            Button("Cancel") {
                isEditing = false
            }
            .buttonStyle(.bordered)
            .buttonBorderShape(.capsule)
            .controlSize(.small)
        }
    }
    
    private var viewControls: some View {
        HStack {
            Text(item.category ?? "Food & Drink")
                .font(.caption)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(.blue.opacity(0.1))
                .foregroundStyle(.blue)
                .clipShape(Capsule())
            
            Spacer()
            
            Button {
                isEditing = true
            } label: {
                Label("Edit", systemImage: "pencil")
                    .font(.subheadline)
                    .foregroundStyle(.blue)
            }
            .buttonStyle(.plain)
            
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Delete", systemImage: "trash")
                    .font(.subheadline)
            }
            .buttonStyle(.plain)
        }
    }
    
    private func saveChanges() {
        let amountDecimal = decimalFromString(editedAmount)
        let amountString = amountDecimal != nil ? String(describing: amountDecimal!) : nil
        onUpdate(editedName, amountString, selectedCategory)
        isEditing = false
    }
    
    private func decimalFromString(_ string: String) -> Decimal? {
        let formatter = NumberFormatter()
        formatter.locale = Locale.current
        formatter.numberStyle = .decimal
        return formatter.number(from: string)?.decimalValue
    }
    
    private func formatAmount(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter.string(from: amount as NSDecimalNumber) ?? "0.00"
    }
}

// MARK: - Image Picker

struct ImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    var sourceType: UIImagePickerController.SourceType
    @Environment(\.dismiss) var dismiss
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker
        
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.image = image
            }
            parent.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}


//import SwiftUI
//import PhotosUI
//import Translation
//internal import Auth
//
//struct ReceiptScannerView: View {
//    @EnvironmentObject var authViewModel: AuthViewModel
//    @StateObject private var viewModel = ReceiptScannerViewModel()
//    
//    @State private var selectedImage: PhotosPickerItem?
//    @State private var showCamera = false
//    @State private var capturedImage: UIImage?
//    
//    var body: some View {
//        NavigationView {
//            ZStack {
//                if viewModel.scannedReceipt == nil {
//                    // Image selection view
//                    VStack(spacing: 30) {
//                        Image(systemName: "doc.text.viewfinder")
//                            .font(.system(size: 80))
//                            .foregroundColor(.blue)
//                        
//                        Text("Scan Receipt")
//                            .font(.title)
//                            .fontWeight(.bold)
//                        
//                        Text("Take a photo or select an image of your receipt from Bulgarian stores")
//                            .foregroundColor(.gray)
//                            .multilineTextAlignment(.center)
//                            .padding(.horizontal)
//                        
//                        VStack(spacing: 15) {
//                            Button(action: { showCamera = true }) {
//                                Label("Take Photo", systemImage: "camera.fill")
//                                    .frame(maxWidth: .infinity)
//                                    .padding()
//                                    .background(Color.blue)
//                                    .foregroundColor(.white)
//                                    .cornerRadius(10)
//                            }
//                            
//                            PhotosPicker(selection: $selectedImage,
//                                       matching: .images) {
//                                Label("Choose from Library", systemImage: "photo.fill")
//                                    .frame(maxWidth: .infinity)
//                                    .padding()
//                                    .background(Color.blue.opacity(0.1))
//                                    .foregroundColor(.blue)
//                                    .cornerRadius(10)
//                            }
//                        }
//                        .padding(.horizontal)
//                        
//                        // Help text
//                        VStack(alignment: .leading, spacing: 8) {
//                            Text("Tips for best results:")
//                                .font(.headline)
//                                .padding(.top)
//                            
//                            HStack(alignment: .top, spacing: 8) {
//                                Text("•")
//                                Text("Ensure receipt is flat and well-lit")
//                            }
//                            HStack(alignment: .top, spacing: 8) {
//                                Text("•")
//                                Text("Hold camera steady")
//                            }
//                            HStack(alignment: .top, spacing: 8) {
//                                Text("•")
//                                Text("Works best with Kaufland, Lidl, Billa receipts")
//                            }
//                        }
//                        .font(.caption)
//                        .foregroundColor(.secondary)
//                        .padding(.horizontal)
//                    }
//                } else {
//                    // Receipt review view
//                    ReceiptReviewView(viewModel: viewModel)
//                }
//                
//                if viewModel.isScanning || viewModel.isTranslating {
//                    Color.black.opacity(0.4)
//                        .ignoresSafeArea()
//                    
//                    VStack(spacing: 20) {
//                        ProgressView()
//                            .scaleEffect(1.5)
//                            .tint(.white)
//                        
//                        Text(viewModel.isTranslating ? "Translating..." : "Scanning receipt...")
//                            .foregroundColor(.white)
//                            .font(.headline)
//                    }
//                    .padding(30)
//                    .background(Color.black.opacity(0.7))
//                    .cornerRadius(15)
//                }
//            }
//            .navigationTitle("Scan Receipt")
//            .navigationBarTitleDisplayMode(.large)
//            .sheet(isPresented: $showCamera) {
//                ImagePicker(image: $capturedImage, sourceType: .camera)
//            }
//            .onChange(of: selectedImage) { _, newValue in
//                Task {
//                    if let data = try? await newValue?.loadTransferable(type: Data.self),
//                       let image = UIImage(data: data) {
//                        await viewModel.scanReceipt(from: image)
//                    }
//                }
//            }
//            .onChange(of: capturedImage) { _, newImage in
//                if let image = newImage {
//                    Task {
//                        await viewModel.scanReceipt(from: image)
//                    }
//                }
//            }
//            .translationTask(viewModel.translationConfiguration) { session in
//                if #available(iOS 18.0, *) {
//                    await viewModel.performBatchTranslation(using: session)
//                }
//            }
//            .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
//                Button("OK") {
//                    viewModel.errorMessage = nil
//                }
//            } message: {
//                if let error = viewModel.errorMessage {
//                    Text(error)
//                }
//            }
//            .alert("Success", isPresented: $viewModel.showSuccess) {
//                Button("OK") {
//                    viewModel.reset()
//                }
//            } message: {
//                Text("Expenses have been added successfully!")
//            }
//        }
//    }
//}
//
//struct ReceiptReviewView: View {
//    @EnvironmentObject var authViewModel: AuthViewModel
//    @ObservedObject var viewModel: ReceiptScannerViewModel
//    
//    let categories = ["Food & Drink", "Home", "Rent & Utilities", "Gold/Silver", "ETFs", "Transport", "Telecom", "Crochet", "Fun", "Eating Out", "Work", "Other"]
//    
//    var body: some View {
//        guard let receipt = viewModel.scannedReceipt else { return AnyView(EmptyView()) }
//        
//        return AnyView(
//            VStack(spacing: 0) {
//                // Header
//                VStack(spacing: 4) {
//                    if let storeName = receipt.storeName {
//                        Text(storeName)
//                            .font(.title2)
//                            .fontWeight(.bold)
//                    }
//                    HStack {
//                        Text("Total:")
//                            .font(.headline)
//                        Text(formatAmount(receipt.total, currency: receipt.currency))
//                            .font(.title2)
//                            .fontWeight(.bold)
//                            .foregroundColor(.blue)
//                    }
//                    .padding(.top, 2)
//                }
//                .padding()
//
//                // Items list
//                List {
//                    ForEach(Array(receipt.items.enumerated()), id: \.element.id) { index, item in
//                        ReceiptItemRow(
//                            item: item,
//                            index: index,
//                            categories: categories,
//                            onUpdate: { name, amount, category in
//                                viewModel.updateItem(at: index, name: name, amount: amount, category: category)
//                            },
//                            onDelete: {
//                                viewModel.removeItem(at: index)
//                            }
//                        )
//                    }
//                }
//                .listStyle(.plain)
//                
//                // Action buttons
//                VStack(spacing: 12) {
//                    Button(action: {
//                        guard let user = authViewModel.currentUser else {
//                            print("No current user")
//                            return
//                        }
//                        
//                        let accountId = user.id
//                        print("User ID: \(user.id)")
//                        
//                        Task {
//                            await viewModel.saveToExpenses(accountId: accountId)
//                        }
//                    }) {
//                        if viewModel.isSaving {
//                            ProgressView()
//                                .tint(.white)
//                        } else {
//                            Text("Add to Expenses")
//                                .fontWeight(.semibold)
//                        }
//                    }
//                    .frame(maxWidth: .infinity)
//                    .padding()
//                    .background(Color.blue)
//                    .foregroundColor(.white)
//                    .cornerRadius(10)
//                    .disabled(viewModel.isSaving || receipt.items.isEmpty)
//                    
//                    Button("Scan Another Receipt") {
//                        viewModel.reset()
//                    }
//                    .foregroundColor(.blue)
//                }
//                .padding()
//                .background(Color(.systemBackground))
//            }
//        )
//    }
//    
//    private func formatAmount(_ amount: Decimal, currency: String) -> String {
//        let formatter = NumberFormatter()
//        formatter.numberStyle = .currency
//        formatter.currencyCode = currency
//        return formatter.string(from: amount as NSDecimalNumber) ?? "\(currency) 0.00"
//    }
//}
//
//struct ReceiptItemRow: View {
//    let item: ReceiptItem
//    let index: Int
//    let categories: [String]
//    let onUpdate: (String?, String?, String?) -> Void
//    let onDelete: () -> Void
//    
//    @State private var isEditing = false
//    @State private var editedName: String
//    @State private var editedAmount: String
//    @State private var selectedCategory: String
//    
//    init(item: ReceiptItem, index: Int, categories: [String], onUpdate: @escaping (String?, String?, String?) -> Void, onDelete: @escaping () -> Void) {
//        self.item = item
//        self.index = index
//        self.categories = categories
//        self.onUpdate = onUpdate
//        self.onDelete = onDelete
//        
//        _editedName = State(initialValue: item.translatedName ?? item.displayName)
//        _editedAmount = State(initialValue: String(describing: item.amount))
//        _selectedCategory = State(initialValue: item.category ?? "Food & Drink")
//    }
//    
//    var body: some View {
//        VStack(alignment: .leading, spacing: 8) {
//            HStack {
//                VStack(alignment: .leading, spacing: 2) {
//                    if isEditing {
//                        TextField("Item name", text: $editedName)
//                        .textFieldStyle(.roundedBorder)
//                        .onAppear {
//                            // sync the latest translation whenever editing starts
//                            editedName = item.translatedName ?? item.displayName
//                        }
//                    } else {
//                        Text(item.displayName)
//                            .font(.headline)
//                        
//                        if item.name != item.displayName {
//                            Text(item.name)
//                                .font(.caption)
//                                .foregroundColor(.gray)
//                        }
//                    }
//                }
//                
//                Spacer()
//                
//                if isEditing {
//                    TextField("Amount", text: $editedAmount)
//                        .textFieldStyle(.roundedBorder)
//                        .keyboardType(.decimalPad)
//                        .frame(width: 80)
//                } else {
//                    Text(formatAmount(item.amount))
//                        .font(.headline)
//                        .foregroundColor(.blue)
//                }
//            }
//            
//            HStack {
//                if isEditing {
//                    Picker("Category", selection: $selectedCategory) {
//                        ForEach(categories, id: \.self) { category in
//                            Text(category).tag(category)
//                        }
//                    }
//                    .pickerStyle(.menu)
//                    
//                    Spacer()
//                    
//                    Button(action: {
//                        let amountDecimal = decimalFromString(editedAmount)
//                        onUpdate(editedName, amountDecimal != nil ? String(describing: amountDecimal!) : nil, selectedCategory)
//                        isEditing = false
////                        onUpdate(editedName, editedAmount, selectedCategory)
////                        isEditing = false
//                    }) {
//                        Text("Done")
//                            .fontWeight(.semibold)
//                    }
//                    .buttonStyle(.borderedProminent)
//                    .buttonBorderShape(.capsule)
//                    .controlSize(.small)
//                    
//                    Button(action: {
//                        isEditing = false
//                    }) {
//                        Text("Cancel")
//                    }
//                    .buttonStyle(.bordered)
//                    .buttonBorderShape(.capsule)
//                    .controlSize(.small)
//                } else {
//                    Text(item.category ?? "Food & Drink")
//                        .font(.caption)
//                        .padding(.horizontal, 8)
//                        .padding(.vertical, 4)
//                        .background(Color.blue.opacity(0.1))
//                        .foregroundColor(.blue)
//                        .cornerRadius(4)
//                    
//                    Spacer()
//                    
//                    Button(action: {
//                        isEditing = true
//                    }) {
//                        HStack(spacing: 4) {
//                            Image(systemName: "pencil")
//                            Text("Edit")
//                        }
//                        .foregroundColor(.blue)
//                        .font(.subheadline)
//                    }
//                    .buttonStyle(.plain)
//                    
//                    Button(action: onDelete) {
//                        HStack(spacing: 4) {
//                            Image(systemName: "trash")
//                            Text("Delete")
//                        }
//                        .foregroundColor(.red)
//                        .font(.subheadline)
//                    }
//                    .buttonStyle(.plain)
//                }
//            }
//        }
//        .padding(.vertical, 8)
//    }
//    
//    func decimalFromString(_ string: String) -> Decimal? {
//        let formatter = NumberFormatter()
//        formatter.locale = Locale.current  // This will respect EU comma decimal
//        formatter.numberStyle = .decimal
//        return formatter.number(from: string)?.decimalValue
//    }
//    
//    private func formatAmount(_ amount: Decimal) -> String {
//        let formatter = NumberFormatter()
//        formatter.numberStyle = .decimal
//        formatter.minimumFractionDigits = 2
//        formatter.maximumFractionDigits = 2
//        return formatter.string(from: amount as NSDecimalNumber) ?? "0.00"
//    }
//}
//
//// Camera/Photo picker
//struct ImagePicker: UIViewControllerRepresentable {
//    @Binding var image: UIImage?
//    var sourceType: UIImagePickerController.SourceType
//    @Environment(\.dismiss) var dismiss
//    
//    func makeUIViewController(context: Context) -> UIImagePickerController {
//        let picker = UIImagePickerController()
//        picker.sourceType = sourceType
//        picker.delegate = context.coordinator
//        return picker
//    }
//    
//    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
//    
//    func makeCoordinator() -> Coordinator {
//        Coordinator(self)
//    }
//    
//    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
//        let parent: ImagePicker
//        
//        init(_ parent: ImagePicker) {
//            self.parent = parent
//        }
//        
//        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
//            if let image = info[.originalImage] as? UIImage {
//                parent.image = image
//            }
//            parent.dismiss()
//        }
//        
//        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
//            parent.dismiss()
//        }
//    }
//}
