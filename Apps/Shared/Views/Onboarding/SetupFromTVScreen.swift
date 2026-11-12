#if !os(tvOS)
    import AntennaCore
    import SwiftData
    import SwiftUI

    /// "Set up Apple TV" on iPhone, iPad and Mac
    /// (iphone-as-setup-device/scanning-opens-the-setup-form-on-the-iphone,
    /// iphone-as-setup-device/the-iphone-shows-the-source-on-its-way):
    /// onboarding's form under the "Opened from your Apple TV" banner, then
    /// "Sending to your Apple TV" after Connect, which cannot be swiped or
    /// escaped away, then onboarding's checklist on Continue. A damaged
    /// link opens the plain "Add a source" form, and a newer one adds a
    /// line asking to update.
    struct SetupFromTVScreen: View {
        let request: SetupInbox.Request
        /// Continue: the link's code counts as used in this launch.
        let use: (SetupLink) -> Void
        /// Closes the sheet.
        let close: () -> Void
        @Environment(\.guideStore) private var guideStore
        @Environment(\.modelContext) private var context
        @Query private var records: [SourceRecord]
        @State private var model = OnboardingModel(connector: .app, clipboard: .system)
        @State private var step = Step.form
        @State private var delivery: SetupDelivery?

        enum Step: Equatable {
            case form
            case sending
            case ready
        }

        var body: some View {
            NavigationStack {
                content
            }
            .preferredColorScheme(.dark)
            .interactiveDismissDisabled(step != .form || model.connecting)
            .task {
                if model.setupDependencies == nil { model.setupDependencies = .live(guide: guideStore) }
            }
            .task(id: delivery.map(ObjectIdentifier.init)) {
                await delivery?.run()
            }
        }

        private var link: SetupLink? {
            if case .setup(let link) = request.kind { return link }
            return nil
        }

        @ViewBuilder private var content: some View {
            switch step {
            case .form:
                form
                    .navigationTitle(link == nil ? "Add a source" : "Set up Apple TV")
                    #if os(iOS)
                        .navigationBarTitleDisplayMode(.inline)
                    #endif
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") {
                                model.cancel()
                                close()
                            }
                            .accessibilityIdentifier("onboarding.fromTV.cancel")
                        }
                    }
            case .sending:
                SetupFromTV.Sending(
                    device: SetupDevice.name, sourceName: model.connection?.descriptor.name ?? "", delivery: deliveryState
                ) {
                    if let link { use(link) }
                    step = .ready
                }
                .navigationTitle("Set up Apple TV")
                #if os(iOS)
                    .navigationBarTitleDisplayMode(.inline)
                #endif
                .navigationBarBackButtonHidden()
            case .ready:
                OnboardingProgressScreen(model: model, signedInToICloud: ICloudAccount.isSignedIn(), finish: { _ in finish() }) {}
            }
        }

        private var form: some View {
            OnboardingForm.Phone(
                fields: $model.fields, revealsPassword: $model.revealsPassword,
                status: .init(error: model.error, connecting: model.connecting, clipboard: model.clipboardOffer),
                actions: .init(choose: { model.choose($0) }, connect: connect, fillIn: { model.fillIn() })
            ) {
                switch request.kind {
                case .setup:
                    SetupFromTV.Banner(device: SetupDevice.name, existing: records.filter { $0.url != nil }.count)
                case .newer:
                    SetupFromTV.UpdateLine(device: SetupDevice.name)
                case .damaged:
                    EmptyView()
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier(link == nil ? "onboarding.form" : "onboarding.fromTV")
            .task { await model.lookForLink() }
        }

        private var deliveryState: SetupFromTV.Delivery {
            switch delivery?.state ?? .sending {
            case .sending: .sending
            case .sent: .sent
            case .notSent: .notSent
            case .notSignedIn: .notSignedIn
            }
        }

        /// Connect as onboarding's; on success the form becomes the sending
        /// screen for a link from the Apple TV, or the checklist otherwise.
        private func connect() {
            Task {
                let started = Date.now
                await model.connect(into: context)
                guard model.connection != nil else { return }
                guard link != nil else { return step = .ready }
                delivery = SetupDelivery(savedAt: started, dependencies: .app)
                step = .sending
            }
        }

        private func finish() {
            model.finish()
            close()
        }
    }

    /// The name the sheets use for this device.
    enum SetupDevice {
        static var name: String {
            #if os(macOS)
                "Mac"
            #else
                UIDevice.current.userInterfaceIdiom == .pad ? "iPad" : "iPhone"
            #endif
        }
    }
#endif
