import SwiftUI

struct ExpandableNavigationButtons: View {
    let canGoToOldest: Bool
    let canGoPrevious: Bool
    let canGoNext: Bool
    let canGoToLatest: Bool

    let onOldest: () -> Void
    let onPrevious: () -> Void
    let onNext: () -> Void
    let onLatest: () -> Void

    @State private var isExpanded = false
    @State private var autoCloseTask: Task<Void, Never>?
    @State private var longPressTask: Task<Void, Never>?
    @State private var didTriggerLongPress = false
    @Namespace private var namespace

    private let autoCloseDelay: TimeInterval = 3.0

    var body: some View {
        if #available(iOS 26.0, *) {
            expandableButtons
        } else {
            legacyButtons
        }
    }

    @available(iOS 26.0, *)
    private var expandableButtons: some View {
        GlassEffectContainer {
            HStack(spacing: 0) {
                if isExpanded {
                    Button {
                        onOldest()
                        scheduleAutoClose()
                    } label: {
                        Image(systemName: "chevron.left.to.line")
                            .font(.title3)
                                                        .frame(width: 28, height: 28)
                    }
                    .buttonStyle(.glass)
                    .disabled(!canGoToOldest)
                    .opacity(canGoToOldest ? 1 : 0.3)
                    .glassEffectUnion(id: "buttons", namespace: namespace)

                    Button {
                        onPrevious()
                        scheduleAutoClose()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.title3)
                                                        .frame(width: 28, height: 28)
                    }
                    .buttonStyle(.glass)
                    .disabled(!canGoPrevious)
                    .opacity(canGoPrevious ? 1 : 0.3)
                    .glassEffectUnion(id: "buttons", namespace: namespace)

                    Button {
                        onNext()
                        scheduleAutoClose()
                    } label: {
                        Image(systemName: "chevron.right")
                            .font(.title3)
                                                        .frame(width: 28, height: 28)
                    }
                    .buttonStyle(.glass)
                    .disabled(!canGoNext)
                    .opacity(canGoNext ? 1 : 0.3)
                    .glassEffectUnion(id: "buttons", namespace: namespace)

                    Button {
                        onLatest()
                        scheduleAutoClose()
                    } label: {
                        Image(systemName: "chevron.right.to.line")
                            .font(.title3)
                                                        .frame(width: 28, height: 28)
                    }
                    .buttonStyle(.glass)
                    .disabled(!canGoToLatest)
                    .opacity(canGoToLatest ? 1 : 0.3)
                    .glassEffectUnion(id: "buttons", namespace: namespace)
                } else {
                    Button {
                        if !didTriggerLongPress {
                            expand()
                        }
                        didTriggerLongPress = false
                    } label: {
                        Image(systemName: "chevron.left.chevron.right")
                            .font(.title3)
                            .frame(width: 28, height: 28)
                    }
                    .buttonStyle(.glass)
                    .simultaneousGesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { _ in
                                if longPressTask == nil {
                                    longPressTask = Task { @MainActor in
                                        try? await Task.sleep(for: .seconds(0.5))
                                        if !Task.isCancelled {
                                            didTriggerLongPress = true
                                            expandAndStayOpen()
                                        }
                                    }
                                }
                            }
                            .onEnded { _ in
                                longPressTask?.cancel()
                                longPressTask = nil
                            }
                    )
                }
            }
        }
    }

    private var legacyButtons: some View {
        HStack(spacing: 0) {
            Button {
                onOldest()
            } label: {
                Image(systemName: "chevron.left.to.line")
                    .font(.title3)
                                        .frame(width: 28, height: 28)
            }
            .disabled(!canGoToOldest)
            .opacity(canGoToOldest ? 1 : 0.3)

            Divider()
                .frame(height: 30)

            Button {
                onPrevious()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.title3)
                                        .frame(width: 28, height: 28)
            }
            .disabled(!canGoPrevious)
            .opacity(canGoPrevious ? 1 : 0.3)

            Divider()
                .frame(height: 30)

            Button {
                onNext()
            } label: {
                Image(systemName: "chevron.right")
                    .font(.title3)
                                        .frame(width: 28, height: 28)
            }
            .disabled(!canGoNext)
            .opacity(canGoNext ? 1 : 0.3)

            Divider()
                .frame(height: 30)

            Button {
                onLatest()
            } label: {
                Image(systemName: "chevron.right.to.line")
                    .font(.title3)
                                        .frame(width: 28, height: 28)
            }
            .disabled(!canGoToLatest)
            .opacity(canGoToLatest ? 1 : 0.3)
        }
        .background(.regularMaterial)
        .clipShape(Capsule())
        .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
    }

    private func expand() {
        withAnimation(.bouncy) {
            isExpanded = true
        }
        scheduleAutoClose()
    }

    private func expandAndStayOpen() {
        let generator = UIImpactFeedbackGenerator(style: .rigid)
        generator.impactOccurred()
        autoCloseTask?.cancel()
        withAnimation(.bouncy) {
            isExpanded = true
        }
    }

    private func collapse() {
        withAnimation(.bouncy) {
            isExpanded = false
        }
    }

    private func scheduleAutoClose() {
        autoCloseTask?.cancel()
        autoCloseTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(autoCloseDelay))
            if !Task.isCancelled {
                collapse()
            }
        }
    }
}
