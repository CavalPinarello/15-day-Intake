//
//  DebugDataView.swift
//  Zoe Sleep - Sleep Better, Live Longer
//
//  Debug view for inspecting raw questionnaire data
//

import SwiftUI

struct DebugDataView: View {
    @EnvironmentObject var questionnaireManager: QuestionnaireManager

    private var sortedResponseKeys: [String] {
        questionnaireManager.responses.keys.sorted()
    }

    var body: some View {
        List {
            Section {
                HStack {
                    Text("Current Day")
                    Spacer()
                    Text("\(questionnaireManager.currentDay)")
                        .foregroundColor(.secondary)
                }

                HStack {
                    Text("Total Responses")
                    Spacer()
                    Text("\(questionnaireManager.responses.count)")
                        .foregroundColor(.secondary)
                }
            } header: {
                Text("Summary")
            }

            Section {
                if questionnaireManager.responses.isEmpty {
                    Text("No responses recorded yet")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(sortedResponseKeys, id: \.self) { key in
                        if let response = questionnaireManager.responses[key] {
                            ResponseRow(key: key, response: response)
                        }
                    }
                }
            } header: {
                Text("Raw Responses")
            }
        }
        .navigationTitle("Raw Data")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Response Row

private struct ResponseRow: View {
    let key: String
    let response: QuestionResponse

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(key)
                .font(.caption.monospaced())
                .foregroundColor(.orange)

            if let stringValue = response.stringValue {
                Text(stringValue)
                    .font(.subheadline)
            }
            if let numberValue = response.numberValue {
                Text("\(numberValue, specifier: "%.1f")")
                    .font(.subheadline)
            }
            if let arrayValue = response.arrayValue, !arrayValue.isEmpty {
                Text(arrayValue.joined(separator: ", "))
                    .font(.subheadline)
            }
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    NavigationStack {
        DebugDataView()
            .environmentObject(QuestionnaireManager.shared)
    }
}
