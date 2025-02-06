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
    @State private var selectedCompany: String? = nil
    @State private var showingDeleteAllAlert = false
    
    // Cache calendar instance
    private let calendar = Calendar.current
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .medium
        return formatter
    }()
    
    private var filteredSessions: [WorkSession] {
        var sessions = store.sessions.sorted(by: { $0.startTime > $1.startTime })
        
        // First filter by company if selected
        if let company = selectedCompany {
            if company == "Other" {
                sessions = sessions.filter { $0.companyName.isEmpty }
            } else {
                sessions = sessions.filter { $0.companyName == company }
            }
        }
        
        // Then filter by date if needed
        if !showAllData {
            let startOfDay = calendar.startOfDay(for: startDate)
            let endOfDay = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: endDate) ?? endDate
            
            sessions = sessions.filter { session in
                let sessionDate = session.startTime
                return sessionDate >= startOfDay && sessionDate <= endOfDay
            }
        }
        
        return sessions
    }
    
    private var uniqueCompanies: [String] {
        var companies = Set(store.sessions.map { $0.companyName }).filter { !$0.isEmpty }
        // Check if there are any sessions without company names
        if store.sessions.contains(where: { $0.companyName.isEmpty }) {
            companies.insert("Other")
        }
        return Array(companies).sorted()
    }
    
    // Cache total hours calculation
    private var totalHoursInRange: Double {
        filteredSessions.reduce(0) { $0 + $1.totalHours }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    // Company Selection
                    VStack(spacing: 16) {
                        Menu {
                            Button(action: {
                                selectedCompany = nil
                            }) {
                                HStack {
                                    Text("All Companies")
                                    if selectedCompany == nil {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                            
                            if !uniqueCompanies.isEmpty {
                                Divider()
                                
                                ForEach(uniqueCompanies, id: \.self) { company in
                                    Button(action: {
                                        selectedCompany = company
                                    }) {
                                        HStack {
                                            if company == "Other" {
                                                Text("No Company")
                                            } else {
                                                Text(company)
                                            }
                                            if selectedCompany == company {
                                                Image(systemName: "checkmark")
                                            }
                                        }
                                    }
                                }
                            }
                        } label: {
                            HStack {
                                Image(systemName: "building.2")
                                    .foregroundStyle(.blue)
                                Text(selectedCompany.map { $0 == "Other" ? "No Company" : $0 } ?? "All Companies")
                                    .foregroundStyle(.primary)
                                Image(systemName: "chevron.up.chevron.down")
                                    .foregroundStyle(.secondary)
                                    .imageScale(.small)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color(UIColor.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                    }
                    .padding(.top)
                    
                    // View Mode Selection
                    VStack(spacing: 16) {
                        Picker("View Mode", selection: $showAllData) {
                            Text("All Records").tag(true)
                            Text("Date Range").tag(false)
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal)
                        .onChange(of: showAllData) { oldValue, newValue in
                            if !newValue {  // When switching to date range mode
                                // Set default range to last 7 days
                                setDateRange(days: -7)
                            }
                        }
                        
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
                                            Text("Start Date")
                                                .font(.subheadline)
                                                .foregroundColor(.secondary)
                                                .frame(width: 80, alignment: .leading)
                                            
                                            Image(systemName: "calendar")
                                                .foregroundColor(.blue)
                                            DatePicker("", selection: $startDate, in: ...endDate, displayedComponents: [.date])
                                                .datePickerStyle(.compact)
                                                .labelsHidden()                                                  
                                        }
                                        .onChange(of: startDate) { _, newValue in
                                            startDate = newValue
                                        }
                                        
                                        HStack {
                                            Text("End Date")
                                                .font(.subheadline)
                                                .foregroundColor(.secondary)
                                                .frame(width: 80, alignment: .leading)
                                            
                                            Image(systemName: "calendar")
                                                .foregroundColor(.blue)
                                            DatePicker("", selection: $endDate, in: startDate..., displayedComponents: [.date])
                                                .datePickerStyle(.compact)
                                                .labelsHidden()
                                        }
                                        .onChange(of: endDate) { _, newValue in
                                            endDate = newValue
                                        }
                                        
                                        // Quick Date Range Buttons
                                        HStack(spacing: 12) {
                                            QuickDateButton(title: "Last 7 Days", action: { setDateRange(days: -7) })
                                            QuickDateButton(title: "Last 14 Days", action: { setDateRange(days: -14) })
                                            QuickDateButton(title: "Last 30 Days", action: { setDateRange(days: -30) })
                                        }
                                    }
                                    .padding()
                                    .background(Color(UIColor.secondarySystemBackground))
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
                            // Number of sessions first
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Sessions")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Text("\(filteredSessions.count)")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.blue)
                            }
                            Spacer()
                            // Total hours second
                            VStack(alignment: .trailing, spacing: 4) {
                                Text(selectedCompany.map { "Total Hours (\($0))" } ?? 
                                    (showAllData ? "Total Hours (All Time)" : "Total Hours in Range"))
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Text(String(format: "%.1f hrs", totalHoursInRange))
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.blue)
                            }
                        }
                        .padding()
                        .background(Color(UIColor.secondarySystemBackground))
                        .cornerRadius(10)
                    }
                    .padding()
                    
                    // Sessions List
                    LazyVStack {
                        ForEach(filteredSessions) { session in
                            SessionRow(
                                session: session,
                                dateFormatter: dateFormatter,
                                editMode: editMode,
                                isSelected: selectedSessions.contains(session.id),
                                onSelect: { id in
                                    if selectedSessions.contains(id) {
                                        selectedSessions.remove(id)
                                    } else {
                                        selectedSessions.insert(id)
                                    }
                                },
                                onDelete: { session in
                                    withAnimation {
                                        store.deleteSession(session)
                                    }
                                },
                                store: store
                            )
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
                    if editMode == .active {
                        Menu {
                            if !selectedSessions.isEmpty {
                                Button(role: .destructive) {
                                    showingMultiDeleteAlert = true
                                } label: {
                                    Label("Delete Selected (\(selectedSessions.count))", systemImage: "checkmark.circle.fill")
                                }
                            }
                            
                            if !filteredSessions.isEmpty {
                                Button(role: .destructive) {
                                    showingDeleteAllAlert = true
                                } label: {
                                    Label(getDeleteAllButtonLabel(), systemImage: "trash.fill")
                                }
                            }
                        } label: {
                            Image(systemName: "trash")
                                .foregroundColor(.red)
                        }
                        .disabled(selectedSessions.isEmpty && filteredSessions.isEmpty)
                    }
                }
            }
            .environment(\.editMode, $editMode)
        }
        // Single delete alert
        .alert("Delete Session", isPresented: $showingDeleteAlert, presenting: sessionToDelete) { session in
            Button("Delete", role: .destructive) {
                deleteSingleSession(session)
            }
            Button("Cancel", role: .cancel) {
                sessionToDelete = nil
            }
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
        // Delete all filtered sessions alert
        .alert("Delete All Filtered Sessions", isPresented: $showingDeleteAllAlert) {
            Button("Delete \(filteredSessions.count) Sessions", role: .destructive) {
                deleteAllFilteredSessions()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(deleteAllConfirmationMessage)
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
    
    private func deleteSingleSession(_ session: WorkSession) {
        store.deleteSession(session)
        sessionToDelete = nil
    }
    
    private func setDateRange(days: Int) {
        endDate = Date()
        startDate = calendar.date(byAdding: .day, value: days, to: endDate) ?? endDate
    }
    
    private var deleteAllConfirmationMessage: String {
        var message = "Are you sure you want to delete"
        if let company = selectedCompany {
            message += " all sessions for \(company == "Other" ? "sessions without company" : "company '\(company)'")"
        } else {
            message += " all sessions"
        }
        if !showAllData {
            message += " in the selected date range"
        }
        message += "? This action cannot be undone."
        return message
    }
    
    private func deleteAllFilteredSessions() {
        for session in filteredSessions {
            store.deleteSession(session)
        }
        selectedSessions.removeAll()
        editMode = .inactive
    }
    
    private func getDeleteAllButtonLabel() -> String {
        if let company = selectedCompany {
            if company == "Other" {
                return "Delete All Without Company (\(filteredSessions.count))"
            } else {
                return "Delete All for '\(company)' (\(filteredSessions.count))"
            }
        } else if !showAllData {
            return "Delete All in Date Range (\(filteredSessions.count))"
        } else {
            return "Delete All Records (\(filteredSessions.count))"
        }
    }
}

struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

struct SessionRow: View {
    let session: WorkSession
    let dateFormatter: DateFormatter
    let editMode: EditMode
    let isSelected: Bool
    let onSelect: (UUID) -> Void
    let onDelete: (WorkSession) -> Void
    @State private var offset: CGFloat = 0
    @State private var isSwiped = false
    @State private var showingDeleteAlert = false
    @State private var showingEditSheet = false
    @ObservedObject var store: WorkSessionStore
    
    private let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter
    }()
    
    private let dateOnlyFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .none
        formatter.dateStyle = .medium
        return formatter
    }()
    
    private var isSameDay: Bool {
        Calendar.current.isDate(session.startTime, inSameDayAs: session.endTime)
    }
    
    var body: some View {
        ZStack(alignment: .trailing) {
            // Delete button background
            HStack(spacing: 0) {
                Rectangle()
                    .foregroundColor(.blue)
                    .frame(width: 80)
                    .overlay(
                        Button {
                            showingEditSheet = true
                            withAnimation {
                                offset = 0
                                isSwiped = false
                            }
                        } label: {
                            Image(systemName: "pencil")
                                .foregroundColor(.white)
                                .imageScale(.large)
                        }
                    )
                
                Rectangle()
                    .foregroundColor(.red)
                    .frame(width: 80)
                    .overlay(
                        Button {
                            showingDeleteAlert = true
                        } label: {
                            Image(systemName: "trash")
                                .foregroundColor(.white)
                                .imageScale(.large)
                        }
                    )
            }
            
            // Main content
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    if editMode == .active {
                        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(.blue)
                            .onTapGesture {
                                onSelect(session.id)
                            }
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        if isSameDay {
                            Text(dateOnlyFormatter.string(from: session.startTime))
                                .font(.subheadline)
                                .foregroundColor(.primary)
                                .fontWeight(.medium)
                            HStack(spacing: 8) {
                                Text(timeFormatter.string(from: session.startTime))
                                Text("→")
                                Text(timeFormatter.string(from: session.endTime))
                            }
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        } else {
                            Text(dateFormatter.string(from: session.startTime))
                                .font(.subheadline)
                                .foregroundColor(.primary)
                                .fontWeight(.medium)
                            Text(dateFormatter.string(from: session.endTime))
                                .font(.subheadline)
                                .foregroundColor(.primary)
                                .fontWeight(.medium)
                        }
                        
                        if !session.companyName.isEmpty {
                            Text(session.companyName)
                                .font(.caption)
                                .foregroundColor(.blue)
                                .lineLimit(1)
                        }
                        Text(session.locationString)
                            .font(.caption)
                            .foregroundColor(Color(UIColor.systemGreen))
                            .lineLimit(1)
                        if !session.note.isEmpty {
                            Text(session.note)
                                .font(.caption)
                                .foregroundColor(.gray)
                                .lineLimit(2)
                                .padding(.top, 2)
                        }
                    }
                    
                    Spacer()
                    
                    Text(String(format: "%.1f hrs", session.totalHours))
                        .font(.headline)
                        .foregroundColor(.blue)
                        .fontWeight(.bold)
                }
            }
            .padding()
            .background(Color(UIColor.systemBackground))
            .cornerRadius(10)
            .shadow(color: .gray.opacity(0.1), radius: 2, x: 0, y: 1)
            .offset(x: offset)
            .simultaneousGesture(
                DragGesture()
                    .onChanged { gesture in
                        if gesture.translation.width < 0 {
                            offset = max(gesture.translation.width, -160) // Updated to accommodate both buttons
                        }
                    }
                    .onEnded { gesture in
                        withAnimation {
                            if gesture.translation.width < -40 {
                                offset = -160 // Updated to accommodate both buttons
                                isSwiped = true
                            } else {
                                offset = 0
                                isSwiped = false
                            }
                        }
                    }
            )
            .simultaneousGesture(
                TapGesture()
                    .onEnded {
                        if isSwiped {
                            withAnimation {
                                offset = 0
                                isSwiped = false
                            }
                        }
                    }
            )
        }
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .sheet(isPresented: $showingEditSheet) {
            NavigationStack {
                EditSessionView(session: session, store: store)
            }
            .presentationDetents([.medium])
        }
        .alert("Delete Session", isPresented: $showingDeleteAlert) {
            Button("Delete", role: .destructive) {
                withAnimation {
                    onDelete(session)
                    offset = 0
                    isSwiped = false
                }
            }
            Button("Cancel", role: .cancel) {
                withAnimation {
                    offset = 0
                    isSwiped = false
                }
            }
        } message: {
            Text("Are you sure you want to delete this work session?")
        }
    }
}

struct EditSessionView: View {
    let session: WorkSession
    @ObservedObject var store: WorkSessionStore
    @State private var startTime: Date
    @State private var endTime: Date
    @State private var location: String
    @State private var note: String
    @State private var companyName: String
    @Environment(\.dismiss) private var dismiss
    
    private let maxWords = 30
    
    private var wordCount: Int {
        note.split(separator: " ").count
    }
    
    private var isWordLimitReached: Bool {
        wordCount >= maxWords
    }
    
    init(session: WorkSession, store: WorkSessionStore) {
        self.session = session
        self.store = store
        _startTime = State(initialValue: session.startTime)
        _endTime = State(initialValue: session.endTime)
        _location = State(initialValue: session.locationString)
        _note = State(initialValue: session.note)
        _companyName = State(initialValue: session.companyName)
    }
    
    var body: some View {
        Form {
            Section("Time") {
                DatePicker("Start Time", selection: $startTime)
                DatePicker("End Time", selection: $endTime, in: startTime...)
            }
            
            Section("Company") {
                TextField("Company Name", text: $companyName)
                    .textInputAutocapitalization(.words)
            }
            
            Section("Location") {
                TextField("Location", text: $location)
            }
            
            Section {
                TextField("Add notes here...", text: $note, axis: .vertical)
                    .lineLimit(3...6)
                    .onChange(of: note) { oldValue, newValue in
                        let words = newValue.split(separator: " ")
                        if words.count > maxWords {
                            note = words.prefix(maxWords).joined(separator: " ")
                        }
                    }
                
                Text("\(wordCount)/\(maxWords) words")
                    .font(.caption)
                    .foregroundColor(isWordLimitReached ? .red : .secondary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            } header: {
                Text("Notes")
            } footer: {
                Text("Maximum \(maxWords) words allowed")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle("Edit Session")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    store.updateSession(
                        session,
                        newStartTime: startTime,
                        newEndTime: endTime,
                        newLocation: location,
                        newNote: note,
                        newCompanyName: companyName
                    )
                    dismiss()
                }
            }
        }
    }
} 