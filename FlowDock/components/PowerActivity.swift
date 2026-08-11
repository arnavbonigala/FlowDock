//
//  PowerActivity.swift
//  FlowDock
//

import Defaults
import SwiftUI

struct PowerReading: Equatable {
    var level: Float
    var isPluggedIn: Bool
    var isCharging: Bool
    var isInLowPowerMode: Bool
    var timeToFullCharge: Int
    var status: String

    var fraction: CGFloat { min(max(CGFloat(level) / 100, 0), 1) }

    var color: Color {
        if isInLowPowerMode { return .yellow }
        if level <= 20 && !isCharging && !isPluggedIn { return .red }
        if isCharging || isPluggedIn || level >= 100 { return .green }
        return .white
    }

    var symbol: String? {
        if isCharging { return "bolt.fill" }
        if isPluggedIn { return "powerplug.fill" }
        return nil
    }

    var timeToFull: String? {
        guard isCharging, timeToFullCharge > 0 else { return nil }
        let hours = timeToFullCharge / 60
        let minutes = timeToFullCharge % 60
        return hours > 0 ? "\(hours)h \(minutes)m" : "\(minutes)m"
    }

    var label: String {
        let base = "\(status), \(Int(level)) percent"
        return timeToFull.map { "\(base), \($0) to full" } ?? base
    }
}

#if DEBUG
extension PowerReading {
    static func stub(
        level: Float,
        isPluggedIn: Bool = false,
        isCharging: Bool = false,
        isInLowPowerMode: Bool = false,
        timeToFullCharge: Int = 0
    ) -> PowerReading {
        PowerReading(
            level: level,
            isPluggedIn: isPluggedIn,
            isCharging: isCharging,
            isInLowPowerMode: isInLowPowerMode,
            timeToFullCharge: timeToFullCharge,
            status: "Unplugged"
        )
    }

    static func selfCheck() {
        assert(stub(level: 12).color == .red)
        assert(stub(level: 12, isPluggedIn: true, isCharging: true).color == .green)
        assert(stub(level: 12, isInLowPowerMode: true).color == .yellow)
        assert(stub(level: 100).color == .green)
        assert(stub(level: 60).color == .white)
        assert(stub(level: 60).symbol == nil)
        assert(stub(level: 60, isPluggedIn: true).symbol == "powerplug.fill")
        assert(stub(level: 60, isPluggedIn: true, isCharging: true).symbol == "bolt.fill")
        assert(stub(level: 60).fraction == 0.6)
        assert(stub(level: 140).fraction == 1)
        assert(stub(level: 40, isCharging: true, timeToFullCharge: 84).timeToFull == "1h 24m")
        assert(stub(level: 40, isCharging: true, timeToFullCharge: 45).timeToFull == "45m")
        assert(stub(level: 40, isCharging: true, timeToFullCharge: 120).timeToFull == "2h 0m")
        assert(stub(level: 40, isCharging: true).timeToFull == nil)
        assert(stub(level: 40, timeToFullCharge: 45).timeToFull == nil)
    }
}
#endif

extension Activity {
    static let powerID = "power"
    static let powerChinSide: CGFloat = 34

    static func power(_ reading: PowerReading) -> Activity {
        Activity(
            id: powerID,
            activityClass: .contextual,
            band: .power,
            label: reading.label,
            chinSideWidth: powerChinSide,
            leading: {
                BatteryGauge(reading: reading)
                    .frame(width: powerChinSide, alignment: .leading)
            },
            trailing: {
                Text("\(Int(reading.level))%")
                    .font(.chinValue)
                    .monospacedDigit()
                    .foregroundStyle(.primary)
                    .frame(width: powerChinSide, alignment: .trailing)
            }
        )
    }
}

extension View {
    func powerActivity(in store: ActivityStore, suppressed: Bool) -> some View {
        modifier(PowerActivityBinder(store: store, suppressed: suppressed))
    }
}

private struct PowerActivityBinder: ViewModifier {
    let store: ActivityStore
    let suppressed: Bool

    @ObservedObject private var battery = BatteryStatusViewModel.shared
    @Default(.showPowerStatusNotifications) private var enabled

    private struct Trigger: Equatable {
        var isPluggedIn: Bool
        var isCharging: Bool
        var isInLowPowerMode: Bool
    }

    private var trigger: Trigger {
        Trigger(
            isPluggedIn: battery.isPluggedIn,
            isCharging: battery.isCharging,
            isInLowPowerMode: battery.isInLowPowerMode
        )
    }

    func body(content: Content) -> some View {
        content.onChange(of: trigger) { _, _ in
            guard enabled, !suppressed else { return }
            store.begin(.power(battery.reading))
        }
    }
}

struct BatteryGauge: View {
    let reading: PowerReading

    var body: some View {
        HStack(spacing: 1) {
            RoundedRectangle(cornerRadius: 3.5, style: .continuous)
                .strokeBorder(.white.opacity(0.4), lineWidth: 1)
                .frame(width: 25, height: 12)
                .overlay(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                        .fill(reading.color)
                        .frame(width: max(2, reading.fraction * 21))
                        .padding(2)
                }
                .overlay {
                    if let symbol = reading.symbol {
                        Image(systemName: symbol)
                            .font(.system(size: 7, weight: .bold))
                            .foregroundStyle(.primary)
                            .shadow(color: .black.opacity(0.6), radius: 1)
                    }
                }

            RoundedRectangle(cornerRadius: 1, style: .continuous)
                .fill(.white.opacity(0.4))
                .frame(width: 1.5, height: 4)
        }
        .accessibilityHidden(true)
    }
}

struct PowerPanelIndicator: View {
    @ObservedObject private var battery = BatteryStatusViewModel.shared
    @Default(.showBatteryIndicator) private var showIndicator
    @Default(.showBatteryPercentage) private var showPercentage

    var body: some View {
        if showIndicator {
            let reading = battery.reading

            HStack(spacing: 4) {
                if let timeToFull = reading.timeToFull {
                    Text(timeToFull)
                        .font(.panelMeta)
                        .monospacedDigit()
                        .foregroundStyle(.tertiary)
                }

                if showPercentage {
                    Text("\(Int(reading.level))%")
                        .font(.panelMeta)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }

                BatteryGauge(reading: reading)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Battery")
            .accessibilityValue(reading.label)
        }
    }
}

#if DEBUG
#Preview {
    VStack(alignment: .trailing, spacing: 12) {
        BatteryGauge(reading: .stub(level: 82, isPluggedIn: true, isCharging: true, timeToFullCharge: 84))
        BatteryGauge(reading: .stub(level: 12))
        BatteryGauge(reading: .stub(level: 55, isInLowPowerMode: true))
        PowerPanelIndicator()
    }
    .padding(24)
    .background(.black)
    .preferredColorScheme(.dark)
}
#endif
