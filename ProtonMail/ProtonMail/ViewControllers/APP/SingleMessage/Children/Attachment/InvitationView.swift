// Copyright (c) 2023 Proton Technologies AG
//
// This file is part of Proton Mail.
//
// Proton Mail is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// Proton Mail is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with Proton Mail. If not, see https://www.gnu.org/licenses/.

import ProtonCoreUIFoundations

final class InvitationView: UIView {
    private let container = SubviewFactory.container
    private let widgetBackground = SubviewFactory.widgetBackground
    private let widgetContainer = SubviewFactory.widgetContainer
    private let widgetDetailsBackground = SubviewFactory.widgetDetailsBackground
    private let widgetDetailsContainer = SubviewFactory.widgetDetailsContainer
    private let titleLabel = SubviewFactory.titleLabel
    private let timeLabel = SubviewFactory.timeLabel
    private let statusContainer = SubviewFactory.statusContainer
    private let statusLabel = SubviewFactory.statusLabel
    private let widgetSeparator = SubviewFactory.widgetSeparator
    private let openInCalendarButton = SubviewFactory.openInCalendarButton
    private let detailsContainer = SubviewFactory.detailsContainer
    private let participantsRow = SubviewFactory.participantsRow

    var onIntrinsicHeightChanged: (() -> Void)?
    var onOpenInCalendarTapped: ((URL) -> Void)?

    private var participantListState = ParticipantListState(isExpanded: false, organizer: nil, attendees: []) {
        didSet {
            updateParticipantsList()
        }
    }

    init() {
        super.init(frame: .zero)

        addSubviews()
        setUpLayout()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func addSubviews() {
        addSubview(container)

        container.addArrangedSubview(widgetBackground)

        widgetBackground.addSubview(widgetContainer)

        widgetContainer.addArrangedSubview(widgetDetailsBackground)
        widgetContainer.addArrangedSubview(statusContainer)
        widgetContainer.addArrangedSubview(widgetSeparator)
        widgetContainer.addArrangedSubview(openInCalendarButton)

        widgetDetailsBackground.addSubviews(widgetDetailsContainer)

        widgetDetailsContainer.addArrangedSubview(titleLabel)
        widgetDetailsContainer.addArrangedSubview(timeLabel)

        statusContainer.addSubview(statusLabel)

        // needed to avoid autolayout warnings raised by adding an empty UIStackView
        detailsContainer.isHidden = true
        container.addArrangedSubview(detailsContainer)
    }

    private func setUpLayout() {
        container.centerInSuperview()
        widgetContainer.fillSuperview()
        widgetDetailsContainer.centerInSuperview()
        statusLabel.centerInSuperview()

        [
            container.topAnchor.constraint(equalTo: topAnchor),
            container.leftAnchor.constraint(equalTo: leftAnchor, constant: 16),

            widgetDetailsContainer.topAnchor.constraint(equalTo: widgetDetailsBackground.topAnchor, constant: 20),
            widgetDetailsContainer.leftAnchor.constraint(equalTo: widgetDetailsBackground.leftAnchor, constant: 16),

            statusLabel.topAnchor.constraint(equalTo: statusContainer.topAnchor, constant: 23),
            statusLabel.leftAnchor.constraint(equalTo: statusContainer.leftAnchor, constant: 20),

            widgetSeparator.heightAnchor.constraint(equalToConstant: 1),

            openInCalendarButton.heightAnchor.constraint(equalToConstant: 48)
        ].activate()
    }

    func populate(with eventDetails: EventDetails) {
        let viewModel = InvitationViewModel(eventDetails: eventDetails)

        titleLabel.set(text: eventDetails.title, preferredFont: .body, weight: .bold, textColor: viewModel.titleColor)
        timeLabel.set(text: viewModel.durationString, preferredFont: .subheadline, textColor: viewModel.titleColor)
        statusLabel.set(text: viewModel.statusString, preferredFont: .subheadline, textColor: viewModel.titleColor)
        statusContainer.isHidden = viewModel.isStatusViewHidden

        openInCalendarButton.addAction(
            UIAction(identifier: .openInCalendar, handler: { [weak self] _ in
                self?.onOpenInCalendarTapped?(eventDetails.calendarAppDeepLink)
            }),
            for: .touchUpInside
        )

        detailsContainer.clearAllViews()
        detailsContainer.addArrangedSubview(SubviewFactory.calendarRow(calendar: eventDetails.calendar))

        if let location = eventDetails.location {
            detailsContainer.addArrangedSubview(SubviewFactory.locationRow(location: location))
        }

        detailsContainer.addArrangedSubview(participantsRow)
        detailsContainer.isHidden = false

        participantListState = .init(
            isExpanded: participantListState.isExpanded,
            organizer: eventDetails.organizer,
            attendees: eventDetails.attendees
        )
    }

    private func updateParticipantsList() {
        participantsRow.contentStackView.clearAllViews()

        if let organizer = participantListState.organizer {
            let participantStackView = makeParticipantStackView(participant: organizer)

            let organizerLabel = SubviewFactory.detailsLabel(
                text: L11n.Event.organizer,
                textColor: ColorProvider.TextWeak
            )
            participantStackView.addArrangedSubview(organizerLabel)

            participantsRow.contentStackView.addArrangedSubview(participantStackView)
        }

        let visibleAttendees: [EventDetails.Participant]
        let expansionButtonTitle: String?

        if participantListState.attendees.count <= 1 {
            visibleAttendees = participantListState.attendees
            expansionButtonTitle = nil
        } else if participantListState.isExpanded {
            visibleAttendees = participantListState.attendees
            expansionButtonTitle = L11n.Event.showLess
        } else {
            visibleAttendees = []
            expansionButtonTitle = String(format: L11n.Event.participantCount, participantListState.attendees.count)
        }

        for attendee in visibleAttendees {
            let participantStackView = makeParticipantStackView(participant: attendee)
            participantsRow.contentStackView.addArrangedSubview(participantStackView)
        }

        if let expansionButtonTitle {
            let action = UIAction { [weak self] _ in
                self?.toggleParticipantListExpansion()
            }

            let button = SubviewFactory.participantListExpansionButton(primaryAction: action)
            button.setTitle(expansionButtonTitle, for: .normal)
            participantsRow.contentStackView.addArrangedSubview(button)
        }

        onIntrinsicHeightChanged?()
    }

    private func makeParticipantStackView(participant: EventDetails.Participant) -> UIStackView {
        let participantStackView = SubviewFactory.participantStackView
        let label = SubviewFactory.detailsLabel(text: participant.email)
        participantStackView.addArrangedSubview(label)

        let tapGR = UITapGestureRecognizer(target: self, action: #selector(didTapParticipant))
        label.isUserInteractionEnabled = true
        label.addGestureRecognizer(tapGR)

        return participantStackView
    }

    @objc
    private func didTapParticipant(sender: UITapGestureRecognizer) {
        guard
            let participantAddressLabel = sender.view as? UILabel,
            let participantAddress = participantAddressLabel.text,
            let url = URL(string: "mailto://\(participantAddress)")
        else {
            return
        }

        UIApplication.shared.open(url)
    }

    private func toggleParticipantListExpansion() {
        participantListState.isExpanded.toggle()
    }
}

private struct SubviewFactory {
    static var container: UIStackView {
        let view = genericStackView
        view.spacing = 8
        return view
    }

    static var widgetBackground: UIView {
        let view = UIView()
        view.setCornerRadius(radius: 24)
        view.layer.borderColor = ColorProvider.SeparatorNorm
        view.layer.borderWidth = 1
        return view
    }

    static var widgetContainer: UIStackView {
        genericStackView
    }

    static var widgetDetailsBackground: UIView {
        let view = UIView()
        view.backgroundColor = ColorProvider.BackgroundSecondary
        return view
    }

    static var widgetDetailsContainer: UIStackView {
        genericStackView
    }

    static var titleLabel: UILabel {
        let view = UILabel()
        view.numberOfLines = 0
        return view
    }

    static var timeLabel: UILabel {
        let view = UILabel()
        view.adjustsFontSizeToFitWidth = true
        return view
    }

    static var statusContainer: UIView {
        UIView()
    }

    static var statusLabel: UILabel {
        let view = UILabel()
        view.numberOfLines = 0
        return view
    }

    static var widgetSeparator: UIView {
        let view = UIView()
        view.backgroundColor = ColorProvider.SeparatorNorm
        return view
    }

    static var openInCalendarButton: UIButton {
        let view = UIButton()
        view.titleLabel?.set(text: nil, preferredFont: .footnote)
        view.setTitle(L11n.ProtonCalendarIntegration.openInCalendar, for: .normal)
        view.setTitleColor(ColorProvider.TextAccent, for: .normal)
        return view
    }

    static var detailsContainer: UIStackView {
        let view = genericStackView
        view.spacing = 8
        return view
    }

    static func calendarRow(calendar: EventDetails.Calendar) -> UIView {
        let row = row(icon: \.circleFilled)
        row.iconImageView.tintColor = UIColor(hexColorCode: calendar.iconColor)

        let label = detailsLabel(text: calendar.name)
        row.contentStackView.addArrangedSubview(label)

        return row
    }

    static func locationRow(location: EventDetails.Location) -> UIView {
        let row = row(icon: \.mapPin)

        let label = detailsLabel(text: location.name)
        row.contentStackView.addArrangedSubview(label)

        return row
    }

    static var participantsRow: ExpandedHeaderRowView {
        row(icon: \.users)
    }

    static var participantStackView: UIStackView {
        genericStackView
    }

    static func participantListExpansionButton(primaryAction: UIAction) -> UIButton {
        let view = UIButton(primaryAction: primaryAction)
        view.contentHorizontalAlignment = .leading
        view.setTitleColor(ColorProvider.TextAccent, for: .normal)
        view.titleLabel?.font = .adjustedFont(forTextStyle: .footnote)
        return view
    }

    private static var genericStackView: UIStackView {
        let view = UIStackView()
        view.axis = .vertical
        view.distribution = .equalSpacing
        return view
    }

    private static func row(icon: KeyPath<ProtonIconSet, ProtonIcon>) -> ExpandedHeaderRowView {
        let row = ExpandedHeaderRowView()
        row.titleLabel.isHidden = true
        row.iconImageView.image = IconProvider[dynamicMember: icon]
        row.contentStackView.spacing = 8
        return row
    }

    static func detailsLabel(text: String, textColor: UIColor = ColorProvider.TextNorm) -> UILabel {
        let view = UILabel()
        view.set(text: text, preferredFont: .footnote, textColor: textColor)
        return view
    }
}

private struct ParticipantListState {
    var isExpanded: Bool
    var organizer: EventDetails.Participant?
    var attendees: [EventDetails.Participant]
}

private extension UIAction.Identifier {
    static let openInCalendar = Self(rawValue: "ch.protonmail.protonmail.action.openInCalendar")
}
