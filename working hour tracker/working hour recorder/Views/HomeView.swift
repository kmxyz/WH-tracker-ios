import SwiftUI

struct HomeView: View {
    @ObservedObject var workSessionStore: WorkSessionStore
    @State private var isWorking = false
    @State private var startTime: Date?
    @State private var endTime: Date?
    @State private var totalHours: Double?
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .medium
        formatter.dateStyle = .medium
        return formatter
    }()
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 30) {
                // Title and Icon
                VStack {
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
                
                // Time Information Display
                VStack(spacing: 20) {
                    TimeInfoView(label: "Start Time", time: startTime, formatter: dateFormatter)
                        .transition(.move(edge: .leading).combined(with: .opacity))
                        .opacity(startTime != nil ? 1 : 0)
                        .animation(.spring(duration: 0.6), value: startTime)
                    
                    TimeInfoView(label: "End Time", time: endTime, formatter: dateFormatter)
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                        .opacity(endTime != nil ? 1 : 0)
                        .animation(.spring(duration: 0.6).delay(0.2), value: endTime)
                    
                    if let hours = totalHours {
                        VStack(spacing: 8) {
                            Text("Total Working Hours")
                                .font(.headline)
                                .foregroundColor(.secondary)
                            Text(String(format: "%.2f", hours))
                                .font(.system(size: 36, weight: .bold))
                                .foregroundColor(.blue)
                                .transition(.scale.combined(with: .opacity))
                                .animation(.spring(duration: 0.6), value: hours)
                            Text("hours")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 20)
                        .padding(.horizontal, 30)
                        .background(
                            RoundedRectangle(cornerRadius: 15)
                                .fill(Color.blue.opacity(0.1))
                                .shadow(color: .blue.opacity(0.1), radius: 5, x: 0, y: 2)
                        )
                        .transition(.scale.combined(with: .opacity))
                        .animation(.spring(duration: 0.8).delay(0.4), value: totalHours)
                    }
                }
                .padding()
                
                Spacer()
                
                // Action Buttons
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
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    private func startWork() {
        withAnimation {
            startTime = Date()
            endTime = nil
            totalHours = nil
            isWorking = true
        }
    }
    
    private func finishWork() {
        let end = Date()
        withAnimation {
            endTime = end
            isWorking = false
            calculateTotalHours()
        }
        
        if let start = startTime, let hours = totalHours {
            let session = WorkSession(startTime: start, endTime: end, totalHours: hours)
            workSessionStore.addSession(session)
        }
    }
    
    private func calculateTotalHours() {
        guard let start = startTime, let end = endTime else { return }
        let timeInterval = end.timeIntervalSince(start)
        totalHours = timeInterval / 3600
    }
} 