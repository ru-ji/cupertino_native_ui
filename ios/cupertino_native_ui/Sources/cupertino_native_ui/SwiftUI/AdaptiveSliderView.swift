import SwiftUI

@available(iOS 15.0, *)
class SliderViewModel: ObservableObject {
    @Published var value: Double = 0.0
    @Published var min: Double = 0.0
    @Published var max: Double = 1.0
    /// From Dart's `divisions`: the slider snaps to `(max - min) / divisions`.
    @Published var step: Double? = nil
    /// iOS 26+: the value the filled track grows from (e.g. 0 in -1...1).
    @Published var neutralValue: Double? = nil
    /// iOS 26+: a tick mark at every step.
    @Published var showTicks: Bool = false
    @Published var minimumIcon: IconConfig? = nil
    @Published var maximumIcon: IconConfig? = nil
    @Published var activeColor: Color? = nil
    @Published var thumbColor: Color? = nil
    @Published var isEnabled: Bool = true

    /// The finger is on the slider. A value pushed from Dart meanwhile is the
    /// echo of an earlier step of this very drag, one round trip late: applied,
    /// it dragged the thumb back under the finger on every frame — on a first
    /// drag in a debug build, so far back that the slider seemed stuck.
    var isEditing = false

    /// Applies a value from Dart unless the user is dragging.
    func setFromDart(_ value: Double) {
        guard !isEditing else { return }
        self.value = value
    }
}

@available(iOS 15.0, *)
struct AdaptiveSliderView: View {
    @ObservedObject var viewModel: SliderViewModel
    var onChanged: ((Double) -> Void)?
    /// `onEditingChanged`: true when the drag starts, false when it ends.
    var onEditing: ((Bool) -> Void)?

    var body: some View {
        slider
            .tint(viewModel.activeColor)
            .disabled(!viewModel.isEnabled)
    }

    private var binding: Binding<Double> {
        Binding(
            get: { viewModel.value },
            set: { newValue in
                viewModel.value = newValue
                onChanged?(newValue)
            })
    }

    private var range: ClosedRange<Double> { viewModel.min...viewModel.max }

    private func editing(_ started: Bool) {
        viewModel.isEditing = started
        onEditing?(started)
    }

    /// One function for both ends: `Slider` wants the two labels the same type.
    @ViewBuilder
    private func edgeLabel(_ icon: IconConfig?) -> some View {
        if let icon { IconView(icon: icon) }
    }

    @ViewBuilder
    private var slider: some View {
        if #available(iOS 26.0, *) {
            if let step = viewModel.step {
                let ticks = viewModel.showTicks
                Slider(
                    value: binding, in: range, step: step,
                    neutralValue: viewModel.neutralValue,
                    label: { EmptyView() },
                    minimumValueLabel: { edgeLabel(viewModel.minimumIcon) },
                    maximumValueLabel: { edgeLabel(viewModel.maximumIcon) },
                    tick: { ticks ? SliderTick($0) : nil },
                    onEditingChanged: editing)
            } else {
                Slider(
                    value: binding, in: range,
                    neutralValue: viewModel.neutralValue,
                    label: { EmptyView() },
                    minimumValueLabel: { edgeLabel(viewModel.minimumIcon) },
                    maximumValueLabel: { edgeLabel(viewModel.maximumIcon) },
                    onEditingChanged: editing)
            }
        } else if let step = viewModel.step {
            Slider(
                value: binding, in: range, step: step,
                label: { EmptyView() },
                minimumValueLabel: { edgeLabel(viewModel.minimumIcon) },
                maximumValueLabel: { edgeLabel(viewModel.maximumIcon) },
                onEditingChanged: editing)
        } else {
            Slider(
                value: binding, in: range,
                label: { EmptyView() },
                minimumValueLabel: { edgeLabel(viewModel.minimumIcon) },
                maximumValueLabel: { edgeLabel(viewModel.maximumIcon) },
                onEditingChanged: editing)
        }
    }
}
