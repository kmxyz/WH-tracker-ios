import SwiftUI
import Charts

struct SummaryView: View {
    @ObservedObject var store: WorkSessionStore
    @State private var selectedPeriod: TimePeriod = .weekly
    @State private var selectedCompany: String? = nil
    
    enum TimePeriod: String, CaseIterable {
        case weekly = "Weekly"
        case biWeekly = "Bi-Weekly"
        case monthly = "Monthly"
    }
    
    private var filteredSessions: [WorkSession] {
        if let company = selectedCompany {
            if company == "Other" {
                return store.sessions.filter { $0.companyName.isEmpty }
            } else {
                return store.sessions.filter { $0.companyName == company }
            }
        }
        return store.sessions
    }
    
    private var uniqueCompanies: [String] {
        var companies = Set(store.sessions.map { $0.companyName }).filter { !$0.isEmpty }
        if store.sessions.contains(where: { $0.companyName.isEmpty }) {
            companies.insert("Other")
        }
        return Array(companies).sorted()
    }
    
    private var weeklyData: [(weekday: Int, hours: Double)] {
        let calendar = Calendar.current
        let now = Date()
        let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now))!
        
        var dailyHours = Array(repeating: 0.0, count: 7)
        
        for session in filteredSessions {
            if let days = calendar.dateComponents([.day], from: weekStart, to: session.startTime).day,
               days >= 0 && days < 7 {
                let weekday = calendar.component(.weekday, from: session.startTime) - 1
                dailyHours[weekday] += session.totalHours
            }
        }
        
        return Array(0...6).map { (weekday: $0, hours: dailyHours[$0]) }
    }
    
    private var biWeeklyData: [(day: Int, hours: Double)] {
        let calendar = Calendar.current
        let now = Date()
        
        // Get the start of today
        let startOfToday = calendar.startOfDay(for: now)
        // Go back 13 days to get full 2 weeks
        let twoWeeksAgo = calendar.date(byAdding: .day, value: -13, to: startOfToday)!
        
        var dailyHours = Array(repeating: 0.0, count: 14)
        
        for session in filteredSessions {
            // Check if session is within the last 14 days
            if session.startTime >= twoWeeksAgo && session.startTime <= now {
                if let days = calendar.dateComponents([.day], from: twoWeeksAgo, to: session.startTime).day,
                   days >= 0 && days < 14 {
                    dailyHours[days] += session.totalHours
                }
            }
        }
        
        return Array(0..<14).map { (day: $0, hours: dailyHours[$0]) }
    }
    
    private var monthlyData: [(day: Int, hours: Double)] {
        let calendar = Calendar.current
        let now = Date()
        let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!
        let daysInMonth = calendar.range(of: .day, in: .month, for: now)?.count ?? 30
        
        var dailyHours = Array(repeating: 0.0, count: daysInMonth)
        
        for session in filteredSessions {
            if calendar.isDate(session.startTime, equalTo: monthStart, toGranularity: .month) {
                let day = calendar.component(.day, from: session.startTime) - 1
                dailyHours[day] += session.totalHours
            }
        }
        
        return Array(0..<daysInMonth).map { (day: $0, hours: dailyHours[$0]) }
    }
    
    private var yAxisMax: Double {
        let maxHours: Double
        switch selectedPeriod {
        case .weekly:
            maxHours = weeklyData.map { $0.hours }.max() ?? 0
        case .biWeekly:
            maxHours = biWeeklyData.map { $0.hours }.max() ?? 0
        case .monthly:
            maxHours = monthlyData.map { $0.hours }.max() ?? 0
        }
        return max(maxHours < 1 ? 1 : 12, maxHours)
    }
    
    private let weekdayNames = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
    
    private func getWeekdayName(for dayOffset: Int) -> String {
        let adjustedDay = (dayOffset + 6) % 7
        return weekdayNames[adjustedDay]
    }
    
    private func calculateStats(for sessions: [(Int, Double)]) -> (total: Double, average: Double, days: Int, longest: Double) {
        let totalHours = sessions.map { $0.1 }.reduce(0, +)
        let workDays = sessions.filter { $0.1 > 0 }.count
        let averageHours = workDays > 0 ? totalHours / Double(workDays) : 0
        let longestSession = sessions.map { $0.1 }.max() ?? 0
        
        return (totalHours, averageHours, workDays, longestSession)
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Company Filter
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
                    
                    // Time Period Picker
                    Picker("Time Period", selection: $selectedPeriod) {
                        ForEach(TimePeriod.allCases, id: \.self) { period in
                            Text(period.rawValue).tag(period)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    
                    switch selectedPeriod {
                    case .weekly:
                        Chart(weeklyData, id: \.weekday) { day in
                            LineMark(
                                x: .value("Day", weekdayNames[day.weekday]),
                                y: .value("Hours", day.hours)
                            )
                            .interpolationMethod(.catmullRom)
                            .symbol(Circle())
                            .foregroundStyle(Color.blue)
                            
                            AreaMark(
                                x: .value("Day", weekdayNames[day.weekday]),
                                y: .value("Hours", day.hours)
                            )
                            .interpolationMethod(.catmullRom)
                            .foregroundStyle(Color.blue.opacity(0.1))
                        }
                        .chartYScale(domain: 0...yAxisMax)
                        .frame(height: 200)
                        .padding()
                        
                        let stats = calculateStats(for: weeklyData.map { ($0.weekday, $0.hours) })
                        SummaryStatsView(
                            period: selectedCompany.map { $0 == "Other" ? "This Week (No Company)" : "This Week (\($0))" } ?? "This Week",
                            totalHours: stats.total,
                            averageHoursPerDay: stats.average,
                            numberOfWorkDays: stats.days,
                            longestSession: stats.longest
                        )
                        
                    case .biWeekly:
                        Chart(biWeeklyData, id: \.day) { day in
                            LineMark(
                                x: .value("Day", day.day + 1),
                                y: .value("Hours", day.hours)
                            )
                            .interpolationMethod(.catmullRom)
                            .symbol(Circle())
                            .foregroundStyle(Color.blue)
                            
                            AreaMark(
                                x: .value("Day", day.day + 1),
                                y: .value("Hours", day.hours)
                            )
                            .interpolationMethod(.catmullRom)
                            .foregroundStyle(Color.blue.opacity(0.1))
                        }
                        .chartXAxis {
                            AxisMarks(values: .stride(by: 2)) { value in
                                if let day = value.as(Int.self) {
                                    AxisValueLabel {
                                        Text(getWeekdayName(for: day - 1))
                                            .font(.caption)
                                    }
                                    AxisTick()
                                    AxisGridLine()
                                }
                            }
                        }
                        .chartYScale(domain: 0...yAxisMax)
                        .frame(height: 200)
                        .padding()
                        
                        let stats = calculateStats(for: biWeeklyData.map { ($0.day, $0.hours) })
                        SummaryStatsView(
                            period: selectedCompany.map { $0 == "Other" ? "Last 2 Weeks (No Company)" : "Last 2 Weeks (\($0))" } ?? "Last 2 Weeks",
                            totalHours: stats.total,
                            averageHoursPerDay: stats.average,
                            numberOfWorkDays: stats.days,
                            longestSession: stats.longest
                        )
                        
                    case .monthly:
                        Chart(monthlyData, id: \.day) { day in
                            LineMark(
                                x: .value("Day", day.day + 1),
                                y: .value("Hours", day.hours)
                            )
                            .interpolationMethod(.catmullRom)
                            .symbol(Circle())
                            .foregroundStyle(Color.blue)
                            
                            AreaMark(
                                x: .value("Day", day.day + 1),
                                y: .value("Hours", day.hours)
                            )
                            .interpolationMethod(.catmullRom)
                            .foregroundStyle(Color.blue.opacity(0.1))
                        }
                        .chartXAxis {
                            AxisMarks(values: Array(stride(from: 1, through: monthlyData.count + 1, by: 4))) { value in
                                if let day = value.as(Int.self) {
                                    AxisValueLabel {
                                        Text("\(day)")
                                            .font(.caption)
                                    }
                                    AxisTick()
                                    AxisGridLine()
                                }
                            }
                        }
                        .chartYScale(domain: 0...yAxisMax)
                        .frame(height: 200)
                        .padding()
                        
                        let stats = calculateStats(for: monthlyData.map { ($0.day, $0.hours) })
                        SummaryStatsView(
                            period: selectedCompany.map { $0 == "Other" ? "This Month (No Company)" : "This Month (\($0))" } ?? "This Month",
                            totalHours: stats.total,
                            averageHoursPerDay: stats.average,
                            numberOfWorkDays: stats.days,
                            longestSession: stats.longest
                        )
                    }
                }
            }
            .navigationTitle("Summary")
        }
    }
}

struct SummaryStatsView: View {
    let period: String
    let totalHours: Double
    let averageHoursPerDay: Double
    let numberOfWorkDays: Int
    let longestSession: Double
    
    var body: some View {
        VStack(spacing: 16) {
            // Total Hours Card
            StatCard(
                title: "Total Hours",
                value: String(format: "%.1f", totalHours),
                subtitle: period,
                iconName: "clock.fill"
            )
            
            HStack(spacing: 12) {
                // Average Hours Card
                StatCard(
                    title: "Daily Average",
                    value: String(format: "%.1f", averageHoursPerDay),
                    subtitle: "hours/day",
                    iconName: "chart.bar.fill"
                )
                
                // Work Days Card
                StatCard(
                    title: "Work Days",
                    value: "\(numberOfWorkDays)",
                    subtitle: "days",
                    iconName: "calendar"
                )
            }
            
            // Longest Session Card
            StatCard(
                title: "Longest Session",
                value: String(format: "%.1f", longestSession),
                subtitle: "hours",
                iconName: "star.fill"
            )
        }
        .padding()
    }
} 