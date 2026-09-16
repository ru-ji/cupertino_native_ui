import SwiftUI

@available(iOS 26.0, *)
struct AdaptiveProgressView: View {
    let value: Double?
    let total: Double
    let label: String?
    let style: Int
    let color: Color?

    var body: some View {
        Group {
            if let val = value {
                // Determinate
                if let labelText = label {
                    ProgressView(labelText, value: val, total: total)
                } else {
                    ProgressView(value: val, total: total)
                }
            } else {
                // Indeterminate
                if let labelText = label {
                    ProgressView(labelText)
                } else {
                    ProgressView()
                }
            }
        }
        .applyStyle(style)
        .applyTint(color)
    }
}

@available(iOS 26.0, *)
extension View {
    @ViewBuilder
    func applyStyle(_ style: Int) -> some View {
        switch style {
        case 1:  // Linear
            self.progressViewStyle(LinearProgressViewStyle())
        case 2:  // Circular
            self.progressViewStyle(CircularProgressViewStyle())
        default:  // Automatic
            self.progressViewStyle(DefaultProgressViewStyle())
        }
    }

    @ViewBuilder
    func applyTint(_ color: Color?) -> some View {
        if let color = color {
            self.tint(color)
        } else {
            self
        }
    }
}
