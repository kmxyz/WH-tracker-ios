import SwiftUI

struct HistoryView: View {
    @ObservedObject var store: WorkSessionStore
    @State private var showingDeleteAlert = false
    @State private var sessionToDelete: WorkSession?
    @State private var editMode: EditMode = .inactive
    @State private var selectedSessions: Set<UUID> = []
    @State private var showingMultiDeleteAlert = false
    @State private var startDate = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
    @State private var endDate = Date()
    @State private var showAllData = true
    @State private var showDatePicker = true
    @State private var scrollOffset: CGFloat = 0
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .medium
        return formatter
    }()
    
    private var filteredSessions: [WorkSession] {
        let sessions = store.sessions.sorted(by: { $0.startTime > $1.startTime })
        if showAllData {
            return sessions
        }
        return sessions.filter { session in
            let isInRange = (startDate...endDate).contains(session.startTime)
            return isInRange
        }
    }
    
    private var totalHoursInRange: Double {
        filteredSessions.reduce(0) { $0 + $1.totalHours }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    // View Mode Selection
                    VStack(spacing: 16) {
                        Picker("View Mode", selection: $showAllData) {
                            Text("All Records").tag(true)
                            Text("Date Range").tag(false)
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal)
                        
                        if !showAllData {
                            // Date Range Controls
                            VStack(spacing: 12) {
                                if showDatePicker {
                                    Text("Select Date Range")
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(.horizontal)
                                    
                                    VStack(spacing: 16) {
                                        HStack {
                                            Image(systemName: "calendar")
                                                .foregroundColor(.blue)
                                            DatePicker("Start Date", selection: $startDate, in: ...endDate, displayedComponents: [.date])
                                                .datePickerStyle(.compact)
                                                .labelsHidden()
                                        }
                                        
                                        HStack {
                                            Image(systemName: "calendar")
                                                .foregroundColor(.blue)
                                            DatePicker("End Date", selection: $endDate, in: startDate..., displayedComponents: [.date])
                                                .datePickerStyle(.compact)
                                                .labelsHidden()
                                        }
                                        
                                        // Quick Date Range Buttons
                                        HStack(spacing: 12) {
                                            QuickDateButton(title: "Last 7 Days", action: { setDateRange(days: -7) })
                                            QuickDateButton(title: "Last 30 Days", action: { setDateRange(days: -30) })
                                            QuickDateButton(title: "Last 90 Days", action: { setDateRange(days: -90) })
                                        }
                                    }
                                    .padding()
                                    .background(Color.gray.opacity(0.1))
                                    .cornerRadius(10)
                                }
                                
                                if !showDatePicker {
                                    Button(action: { withAnimation { showDatePicker = true } }) {
                                        Label("Show Date Picker", systemImage: "calendar")
                                            .foregroundColor(.blue)
                                    }
                                    .padding(.vertical, 8)
                                }
                            }
                        }
                        
                        // Total Hours Card
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(showAllData ? "Total Hours (All Time)" : "Total Hours in Range")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Text(String(format: "%.2f hrs", totalHoursInRange))
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.blue)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 4) {
                                Text("\(filteredSessions.count)")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.blue)
                                Text("sessions")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding()
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(10)
                    }
                    .padding()
                    
                    // Sessions List
                    LazyVStack {
                        ForEach(filteredSessions) { session in
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(dateFormatter.string(from: session.startTime))
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                        Text(dateFormatter.string(from: session.endTime))
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    Spacer()
                                    
                                    Text(String(format: "%.2f hrs", session.totalHours))
                                        .font(.headline)
                                        .foregroundColor(.blue)
                                }
                            }
                            .padding()
                            .background(Color.white)
                            .cornerRadius(10)
                            .shadow(color: .gray.opacity(0.1), radius: 2, x: 0, y: 1)
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    sessionToDelete = session
                                    showingDeleteAlert = true
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .background(GeometryReader { proxy in
                Color.clear.preference(
                    key: ScrollOffsetPreferenceKey.self,
                    value: proxy.frame(in: .named("scroll")).minY
                )
            })
            .coordinateSpace(name: "scroll")
            .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
                let threshold: CGFloat = -50 // Adjust this value to change when the date picker hides
                withAnimation {
                    showDatePicker = value > threshold
                }
            }
            .navigationTitle("Work History")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if !store.sessions.isEmpty {
                        EditButton()
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    if editMode == .active && !selectedSessions.isEmpty {
                        Button(role: .destructive) {
                            showingMultiDeleteAlert = true
                        } label: {
                            Text("Delete (\(selectedSessions.count))")
                                .foregroundColor(.red)
                        }
                    }
                }
            }
            .environment(\.editMode, $editMode)
        }
        // Single delete alert
        .alert("Delete Session", isPresented: $showingDeleteAlert, presenting: sessionToDelete) { session in
            Button("Delete", role: .destructive) {
                store.deleteSession(session)
            }
            Button("Cancel", role: .cancel) {}
        } message: { session in
            Text("Are you sure you want to delete this work session?")
        }
        // Multiple delete alert
        .alert("Delete Selected Sessions", isPresented: $showingMultiDeleteAlert) {
            Button("Delete \(selectedSessions.count) Sessions", role: .destructive) {
                deleteSelectedSessions()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to delete these \(selectedSessions.count) sessions? This action cannot be undone.")
        }
    }
    
    private func deleteSelectedSessions() {
        for id in selectedSessions {
            if let sessionToRemove = store.sessions.first(where: { $0.id == id }) {
                store.deleteSession(sessionToRemove)
            }
        }
        selectedSessions.removeAll()
        editMode = .inactive
    }
    
    private func setDateRange(days: Int) {
        let calendar = Calendar.current
        endDate = Date()
        startDate = calendar.date(byAdding: .day, value: days, to: endDate) ?? endDate
    }
}

struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
} 