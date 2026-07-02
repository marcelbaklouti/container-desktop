import SwiftUI
import AppKit

extension View {
    /// Presents a store's RuntimeIssue as a native alert with a titled reason, an optional
    /// recovery action, and a Copy Details button carrying the failed command and stderr.
    func issueAlert(_ issue: Binding<RuntimeIssue?>, onRemedy: @escaping (RuntimeIssue.Remedy) -> Void) -> some View {
        alert(
            issue.wrappedValue?.title ?? String(localized: "Something Went Wrong"),
            isPresented: Binding(
                get: { issue.wrappedValue != nil },
                set: { if !$0 { issue.wrappedValue = nil } }
            ),
            presenting: issue.wrappedValue
        ) { presented in
            if let label = presented.remedyLabel {
                Button(label) { onRemedy(presented.remedy) }
            }
            if let details = presented.rawDetails {
                Button("Copy Details") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(details, forType: .string)
                }
            }
            Button("OK", role: .cancel) {}
        } message: { presented in
            Text(presented.reason)
        }
    }
}
