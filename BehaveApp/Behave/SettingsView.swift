import SwiftUI

struct SettingsView: View {
    @Binding var frequency: Double
    @Binding var sentences: [String]
    @State private var showingFilePicker = false
    @EnvironmentObject var settingsState: SettingsState
    
    private var frequencyText: String {
        "Prompt Frequency: \(Int(frequency)) minutes"
    }
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Settings")
                .font(.title)
                .padding(.top)
            
            VStack(alignment: .leading, spacing: 10) {
                Text(frequencyText)
                Slider(value: $frequency, in: 1...60, step: 1)
                    .onChange(of: frequency) { newValue in
                        settingsState.frequency = newValue
                    }
            }
            .padding()
            
            VStack(alignment: .leading, spacing: 10) {
                Text("Current Sentences:")
                    .font(.headline)
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 5) {
                        ForEach(sentences, id: \.self) { sentence in
                            Text("• \(sentence)")
                                .lineLimit(1)
                        }
                    }
                }
                .frame(height: 150)
                .padding()
                .background(Color(.textBackgroundColor))
                .cornerRadius(8)
            }
            .padding()
            
            Button("Load Sentences from File") {
                showingFilePicker = true
            }
            .fileImporter(
                isPresented: $showingFilePicker,
                allowedContentTypes: [.text],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let files):
                    guard let selectedFile = files.first else { return }
                    
                    if selectedFile.startAccessingSecurityScopedResource() {
                        defer { selectedFile.stopAccessingSecurityScopedResource() }
                        
                        do {
                            let data = try Data(contentsOf: selectedFile)
                            if let content = String(data: data, encoding: .utf8) {
                                let newSentences = content
                                    .components(separatedBy: .newlines)
                                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                                    .filter { !$0.isEmpty }
                                
                                if !newSentences.isEmpty {
                                    sentences = newSentences
                                }
                            }
                        } catch {
                            print("Error reading file: \(error.localizedDescription)")
                        }
                    }
                case .failure(let error):
                    print("Error selecting file: \(error.localizedDescription)")
                }
            }
            
            Toggle("Launch at Login", isOn: $settingsState.launchAtLogin)
                .padding()
            
            Spacer()
        }
        .frame(width: 400, height: 500)
        .padding()
    }
} 