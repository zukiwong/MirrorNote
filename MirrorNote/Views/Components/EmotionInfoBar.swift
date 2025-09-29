// MirrorNote/Views/Components/EmotionInfoBar.swift
import SwiftUI

struct EmotionInfoBar: View {
    @ObservedObject var vm: EmotionContextViewModel
    @State private var showDatePicker = false

    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 20) {
            // Time
            Button(action: { showDatePicker = true }) {
                VStack(alignment: .leading, spacing: 1) {
                    Text("Time").font(.caption2).foregroundColor(.gray)
                    Text(dateString(vm.date)).font(.system(size: 15)).foregroundColor(.primary)
                }
            }
            .sheet(isPresented: $showDatePicker) {
                DatePicker("Select Date", selection: $vm.date, displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .padding()
            }

            // Location - immersive input
            Button(action: {
                vm.openImmersiveView(for: .place)
            }) {
                VStack(alignment: .leading, spacing: 1) {
                    Text("Location").font(.caption2).foregroundColor(.gray)
                    Text(vm.place.isEmpty ? "Enter" : vm.place)
                        .font(.system(size: 15))
                        .foregroundColor(vm.place.isEmpty ? .gray : .primary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .frame(minWidth: 75, maxWidth: (geometry.size.width - 16 - 60 - 40) / 2, alignment: .leading)
                }
            }
            .buttonStyle(PlainButtonStyle())

            // People - immersive input
            Button(action: {
                vm.openImmersiveView(for: .people)
            }) {
                VStack(alignment: .leading, spacing: 1) {
                    Text("People").font(.caption2).foregroundColor(.gray)
                    Text(vm.people.isEmpty ? "Enter" : vm.people)
                        .font(.system(size: 15))
                        .foregroundColor(vm.people.isEmpty ? .gray : .primary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .frame(minWidth: 75, maxWidth: (geometry.size.width - 16 - 60 - 40) / 2, alignment: .leading)
                }
            }
            .buttonStyle(PlainButtonStyle())
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 8) // Consistent margin with other components
            .padding(.vertical, 8) // Reduce vertical padding
        }
        .frame(height: 40) // 固定高度避免GeometryReader影响布局
    }

    private func dateString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d EEE"
        formatter.locale = Locale(identifier: "en_US")
        return formatter.string(from: date)
    }
}