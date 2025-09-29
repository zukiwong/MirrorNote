import SwiftUI

struct SettingView: View {
    @StateObject private var viewModel = SettingViewModel()
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Title area
                titleSection
                
                // Scrolling content area
                ScrollView {
                    VStack(spacing: 16) {
                    // Choose reply tone settings
                    SettingSection(
                        title: "Choose Reply Tone",
                        isExpanded: viewModel.isReplyToneExpanded,
                        onToggle: viewModel.toggleReplyToneExpansion
                    ) {
                        VStack(alignment: .leading, spacing: 0) {
                            ForEach(ReplyTone.allCases, id: \.self) { tone in
                                SettingOptionRow(
                                    title: tone.rawValue,
                                    subtitle: tone.description,
                                    isSelected: viewModel.isReplyToneSelected(tone),
                                    selectionType: .radio,
                                    onToggle: { viewModel.setReplyTone(tone) }
                                )
                                
                                // Add divider for all except the last one
                                if tone != ReplyTone.allCases.last {
                                    Divider()
                                        .padding(.leading, 30)
                                }
                            }
                        }
                    }
                    
                    // Archive settings
                    SettingSection(
                        title: "Archive Settings",
                        isExpanded: viewModel.isArchiveTimeExpanded,
                        onToggle: viewModel.toggleArchiveTimeExpansion
                    ) {
                        VStack(alignment: .leading, spacing: 0) {
                            ForEach(ArchiveTime.allCases, id: \.self) { time in
                                SettingOptionRow(
                                    title: time.rawValue,
                                    subtitle: nil,
                                    isSelected: viewModel.selectedArchiveTime == time,
                                    selectionType: .radio,
                                    onToggle: { viewModel.setArchiveTime(time) }
                                )
                                
                                // Add divider for all except the last one
                                if time != ArchiveTime.allCases.last {
                                    Divider()
                                        .padding(.leading, 30)
                                }
                            }
                        }
                    }
                    
                    // Data Management settings
                    SettingSection(
                        title: "Data Management",
                        isExpanded: viewModel.isDataManagementExpanded,
                        onToggle: viewModel.toggleDataManagementExpansion
                    ) {
                        VStack(alignment: .leading, spacing: 0) {
                            Button(action: {
                                viewModel.showClearDataConfirmation()
                            }) {
                                HStack(alignment: .top, spacing: 12) {
                                    // Warning icon
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .font(.system(size: 18))
                                        .foregroundColor(.red)
                                    
                                    // Text content
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Clear All Records")
                                            .font(.system(size: 16, weight: .medium))
                                            .foregroundColor(.primary)
                                            .multilineTextAlignment(.leading)
                                        
                                        Text("This will permanently delete all emotion records and messages")
                                            .font(.system(size: 14))
                                            .foregroundColor(.gray)
                                            .multilineTextAlignment(.leading)
                                    }
                                    
                                    Spacer()
                                }
                                .padding(.vertical, 8)
                            }
                            .buttonStyle(PlainButtonStyle())
                            .disabled(viewModel.isClearingData)
                            .opacity(viewModel.isClearingData ? 0.6 : 1.0)
                        }
                    }
                    
                        Spacer(minLength: 100)
                    }
                    .padding(.top, 16)
                }
            }
            .navigationBarHidden(true)
            .alert("Are you sure?", isPresented: $viewModel.showClearDataAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Clear", role: .destructive) {
                    viewModel.clearAllData()
                }
            } message: {
                Text("This action cannot be undone. All emotion records and messages will be permanently deleted.")
            }
            .alert("Success", isPresented: $viewModel.showSuccessAlert) {
                Button("OK") { }
            } message: {
                Text("Data cleared successfully")
            }
        }
    }
    
    // Title area
    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Settings")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(Color("PrimaryText"))
                        .tracking(3)
                    
                    Text("CUSTOMIZE YOUR PREFERENCES")
                        .font(.system(size: 11, weight: .light))
                        .foregroundColor(Color("PrimaryText"))
                        .tracking(3)
                }
                
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 21)
            .background(Color("PrimaryBackground"))
        }
    }
}

