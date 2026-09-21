import SwiftUI

@available(iOS 15.0, *)
class SliderViewModel: ObservableObject {
    @Published var value: Double = 0.0
    @Published var min: Double = 0.0
    @Published var max: Double = 1.0
    @Published var activeColor: Color? = nil
    @Published var thumbColor: Color? = nil
    @Published var isEnabled: Bool = true
}

@available(iOS 15.0, *)
struct AdaptiveSliderView: View {
    @ObservedObject var viewModel: SliderViewModel
    var onChanged: ((Double) -> Void)?

    var body: some View {
        Slider(
            value: Binding(
                get: { viewModel.value },
                set: { newValue in
                    viewModel.value = newValue
                    onChanged?(newValue)
                }
            ), in: viewModel.min...viewModel.max
        )
        .tint(viewModel.activeColor)
        .disabled(!viewModel.isEnabled)
    }
}
