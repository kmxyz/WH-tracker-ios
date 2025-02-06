import SwiftUI
import CoreLocation

struct HomeView: View {
    @ObservedObject var workSessionStore: WorkSessionStore
    @StateObject private var locationManager = LocationManager()
    @State private var isWorking = false
    @State private var startTime: Date?
    @State private var endTime: Date?
    @State private var totalHours: Double?
    @State private var companyName: String = ""
    @State private var newCompanyName: String = ""
    @State private var showingCompanyInput = false
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .medium
        formatter.dateStyle = .medium
        return formatter
    }()
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 25) {
                        // Title and Icon
                        VStack(spacing: 8) {
                            Image(systemName: "clock.badge.checkmark")
                                .imageScale(.large)
                                .font(.system(size: 60))
                                .foregroundStyle(.blue)
                                .symbolEffect(.bounce, options: .repeat(2), value: isWorking)
                            Text("Working Hour Recorder")
                                .font(.title)
                                .fontWeight(.bold)
                        }
                        .padding(.top, 30)
                        
                        // Time and Location Information
                        VStack(spacing: 16) {
                            // Company Name Card
                            InfoCard(
                                title: "Company",
                                isVisible: true
                            ) {
                                HStack {
                                    if companyName.isEmpty {
                                        Text("Tap to add company name")
                                            .foregroundColor(.secondary)
                                            .font(.headline)
                                    } else {
                                        Text(companyName)
                                            .font(.headline)
                                    }
                                    Spacer()
                                    Image(systemName: "building.2")
                                        .foregroundColor(.blue)
                                }
                            }
                            .onTapGesture {
                                showingCompanyInput = true
                            }
                            
                            // Start Time Card
                            InfoCard(
                                title: "Start Time",
                                isVisible: startTime != nil
                            ) {
                                if let time = startTime {
                                    Text(dateFormatter.string(from: time))
                                        .font(.headline)
                                }
                            }
                            
                            // Location Card
                            if isWorking || startTime != nil {
                                InfoCard(
                                    title: "Location",
                                    isVisible: true
                                ) {
                                    VStack(alignment: .leading, spacing: 6) {
                                        if locationManager.permissionDenied {
                                            HStack(spacing: 8) {
                                                Text("Location access denied")
                                                    .foregroundColor(.red)
                                                Button {
                                                    if let url = URL(string: UIApplication.openSettingsURLString) {
                                                        UIApplication.shared.open(url)
                                                    }
                                                } label: {
                                                    Image(systemName: "gear")
                                                        .foregroundColor(.blue)
                                                }
                                            }
                                            Text("Tap the gear icon to open Settings")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        } else {
                                            Text(locationManager.locationString)
                                                .font(.headline)
                                        }
                                    }
                                }
                            }
                            
                            // End Time Card
                            InfoCard(
                                title: "End Time",
                                isVisible: endTime != nil
                            ) {
                                if let time = endTime {
                                    Text(dateFormatter.string(from: time))
                                        .font(.headline)
                                }
                            }
                            
                            // Total Hours Card
                            if let hours = totalHours {
                                InfoCard(
                                    title: "Total Working Hours",
                                    isVisible: true
                                ) {
                                    VStack(spacing: 4) {
                                        Text(String(format: "%.2f", hours))
                                            .font(.system(size: 36, weight: .bold))
                                            .foregroundColor(.blue)
                                        Text("hours")
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                
                // Action Buttons in a fixed container
                VStack {
                    if !isWorking {
                        Button(action: startWork) {
                            ActionButtonView(title: "Start Work", systemImage: "play.circle.fill", color: .green)
                        }
                        .transition(.scale)
                    } else {
                        Button(action: finishWork) {
                            ActionButtonView(title: "Finish Work", systemImage: "stop.circle.fill", color: .red)
                        }
                        .transition(.scale)
                    }
                }
                .padding()
                .background(Color(UIColor.systemBackground))
                .shadow(color: Color.primary.opacity(0.1), radius: 5)
            }
            .navigationBarTitleDisplayMode(.inline)
            .background(Color(UIColor.systemBackground))
            .onAppear {
                locationManager.requestPermission()
                // Restore session state if exists
                if let inProgress = workSessionStore.inProgressSession {
                    startTime = inProgress.startTime
                    isWorking = inProgress.isWorking
                    if isWorking {
                        locationManager.startUpdatingLocation()
                    }
                }
            }
        }
        .sheet(isPresented: $showingCompanyInput) {
            NavigationStack {
                List {
                    Section("Companies") {
                        ForEach(workSessionStore.savedCompanyNames, id: \.self) { name in
                            Button(action: {
                                companyName = name
                                showingCompanyInput = false
                            }) {
                                HStack {
                                    Text(name)
                                    Spacer()
                                    if name == companyName {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(.blue)
                                    }
                                }
                            }
                            .foregroundColor(.primary)
                        }
                        .onDelete { indexSet in
                            indexSet.forEach { index in
                                let name = workSessionStore.savedCompanyNames[index]
                                workSessionStore.removeCompanyName(name)
                            }
                        }
                    }
                    
                    Section("Add New Company") {
                        TextField("Company Name", text: $newCompanyName)
                            .textInputAutocapitalization(.words)
                            .submitLabel(.done)
                    }
                }
                .navigationTitle("Select Company")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            newCompanyName = ""
                            showingCompanyInput = false
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            if !newCompanyName.isEmpty {
                                companyName = newCompanyName
                                workSessionStore.addCompanyName(newCompanyName)
                                newCompanyName = ""
                            }
                            showingCompanyInput = false
                        }
                    }
                }
            }
            .presentationDetents([.medium])
        }
    }
    
    private func startWork() {
        let start = Date()
        withAnimation {
            startTime = start
            endTime = nil
            totalHours = nil
            isWorking = true
        }
        locationManager.startUpdatingLocation()
        workSessionStore.saveInProgressSession(startTime: start, isWorking: true)
    }
    
    private func finishWork() {
        let end = Date()
        withAnimation {
            endTime = end
            isWorking = false
            calculateTotalHours()
        }
        
        if let start = startTime, let hours = totalHours {
            let session = WorkSession(
                startTime: start,
                endTime: end,
                totalHours: hours,
                locationString: locationManager.locationString,
                latitude: locationManager.location?.coordinate.latitude,
                longitude: locationManager.location?.coordinate.longitude,
                companyName: companyName
            )
            workSessionStore.addSession(session)
            workSessionStore.clearInProgressSession()
        }
        
        locationManager.stopUpdatingLocation()
    }
    
    private func calculateTotalHours() {
        guard let start = startTime, let end = endTime else { return }
        let timeInterval = end.timeIntervalSince(start)
        totalHours = timeInterval / 3600
    }
}

// Reusable Info Card View
struct InfoCard<Content: View>: View {
    let title: String
    let isVisible: Bool
    let content: () -> Content
    
    init(
        title: String,
        isVisible: Bool,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.isVisible = isVisible
        self.content = content
    }
    
    var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            content()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(UIColor.systemBackground))
                .shadow(color: Color.primary.opacity(0.1), radius: 5)
        )
        .opacity(isVisible ? 1 : 0)
        .animation(.spring(duration: 0.6), value: isVisible)
    }
} 