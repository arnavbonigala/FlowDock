import Cocoa
import Defaults
import Foundation
import IOKit.ps
import SwiftUI

/// A view model that manages and monitors the battery status of the device
class BatteryStatusViewModel: ObservableObject {

    private var wasCharging: Bool = false
    private var powerSourceChangedCallback: IOPowerSourceCallbackType?
    private var runLoopSource: Unmanaged<CFRunLoopSource>?

    @Published private(set) var levelBattery: Float = 0.0
    @Published private(set) var maxCapacity: Float = 0.0
    @Published private(set) var isPluggedIn: Bool = false
    @Published private(set) var isCharging: Bool = false
    @Published private(set) var isInLowPowerMode: Bool = false
    @Published private(set) var isInitial: Bool = false
    @Published private(set) var timeToFullCharge: Int = 0

    var statusText: String {
        let state: String
        if isCharging {
            state = "Charging"
        } else if isPluggedIn {
            state = levelBattery < maxCapacity ? "Plugged In" : "Charged"
        } else {
            state = "Unplugged"
        }
        return isInLowPowerMode ? "\(state), Low Power" : state
    }

    private let managerBattery = BatteryActivityManager.shared
    private var managerBatteryId: Int?

    static let shared = BatteryStatusViewModel()

    var reading: PowerReading {
        PowerReading(
            level: levelBattery,
            isPluggedIn: isPluggedIn,
            isCharging: isCharging,
            isInLowPowerMode: isInLowPowerMode,
            timeToFullCharge: timeToFullCharge,
            status: statusText
        )
    }

    /// Initializes the view model with a given FlowDockViewModel instance
    /// - Parameter vm: The FlowDockViewModel instance
    private init() {
        setupPowerStatus()
        setupMonitor()
    }

    /// Sets up the initial power status by fetching battery information
    private func setupPowerStatus() {
        let batteryInfo = managerBattery.initializeBatteryInfo()
        updateBatteryInfo(batteryInfo)
    }

    /// Sets up the monitor to observe battery events
    private func setupMonitor() {
        managerBatteryId = managerBattery.addObserver { [weak self] event in
            guard let self = self else { return }
            self.handleBatteryEvent(event)
        }
    }

    /// Handles battery events and updates the corresponding properties
    /// - Parameter event: The battery event to handle
    private func handleBatteryEvent(_ event: BatteryActivityManager.BatteryEvent) {
        switch event {
        case .powerSourceChanged(let isPluggedIn):
            withAnimation {
                self.isPluggedIn = isPluggedIn
            }

        case .batteryLevelChanged(let level):
            withAnimation {
                self.levelBattery = level
            }

        case .lowPowerModeChanged(let isEnabled):
            withAnimation {
                self.isInLowPowerMode = isEnabled
            }

        case .isChargingChanged(let isCharging):
            withAnimation {
                self.isCharging = isCharging
            }

        case .timeToFullChargeChanged(let time):
            withAnimation {
                self.timeToFullCharge = time
            }

        case .maxCapacityChanged(let capacity):
            withAnimation {
                self.maxCapacity = capacity
            }

        case .error(let description):
            NSLog("Battery monitoring reported an error: \(description)")
        }
    }

    /// Updates the battery information with the given BatteryInfo instance
    /// - Parameter batteryInfo: The BatteryInfo instance containing the battery data
    private func updateBatteryInfo(_ batteryInfo: BatteryInfo) {
        withAnimation {
            self.levelBattery = batteryInfo.currentCapacity
            self.isPluggedIn = batteryInfo.isPluggedIn
            self.isCharging = batteryInfo.isCharging
            self.isInLowPowerMode = batteryInfo.isInLowPowerMode
            self.timeToFullCharge = batteryInfo.timeToFullCharge
            self.maxCapacity = batteryInfo.maxCapacity
        }
    }


    deinit {
        if let managerBatteryId: Int = managerBatteryId {
            managerBattery.removeObserver(byId: managerBatteryId)
        }
    }

}
