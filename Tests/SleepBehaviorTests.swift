import Foundation

@main enum SleepBehaviorTests {
    static func main() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        func input(enabled: Bool = true, available: Bool = true, external: Bool = true,
                   percentage: Double? = 70, target: Int? = 80,
                   startedAt: Date? = nil) -> SleepInhibitionInput {
            .init(enabled: enabled, batteryAvailable: available, externalConnected: external,
                  percentage: percentage, target: target, startedAt: startedAt, now: now)
        }

        precondition(SleepInhibitionPolicy.status(for: input(enabled: false)) == .disabled)
        precondition(SleepInhibitionPolicy.status(for: input(external: false)) == .waitingForPower)
        precondition(SleepInhibitionPolicy.status(for: input(available: false)) == .waitingForBattery)
        precondition(SleepInhibitionPolicy.status(for: input(percentage: nil)) == .waitingForBattery)
        precondition(SleepInhibitionPolicy.status(for: input(target: nil)) == .waitingForTarget)
        precondition(SleepInhibitionPolicy.status(for: input(percentage: 79.6)) == .active(current: 80, target: 80))
        precondition(SleepInhibitionPolicy.status(for: input(percentage: 80)) == .targetReached(80))
        precondition(SleepInhibitionPolicy.status(for: input(startedAt: now.addingTimeInterval(-28_801))) == .timedOut)

        var acquired = 0
        var released: [UInt32] = []
        let controller = SleepInhibitionController(acquire: {
            acquired += 1
            return UInt32(40 + acquired)
        }, release: { released.append($0) })
        controller.update(input())
        controller.update(input(startedAt: now))
        precondition(acquired == 1 && released.isEmpty && controller.isActive)
        controller.update(input(percentage: 80, startedAt: now))
        precondition(released == [41] && !controller.isActive && controller.status == .targetReached(80))
        controller.update(input())
        precondition(acquired == 2 && controller.isActive)
        controller.update(input(external: false))
        precondition(released == [41, 42] && !controller.isActive && controller.status == .waitingForPower)
        controller.update(input())
        precondition(acquired == 3 && controller.isActive)
        controller.update(input(available: false))
        precondition(released == [41, 42, 43] && !controller.isActive && controller.status == .waitingForBattery)
        controller.update(input())
        precondition(acquired == 4 && controller.isActive)
        controller.update(input(enabled: false))
        precondition(released == [41, 42, 43, 44] && !controller.isActive && controller.status == .disabled)
        controller.update(input())
        precondition(acquired == 5 && controller.isActive)
        controller.stop()
        precondition(released == [41, 42, 43, 44, 45] && !controller.isActive)

        var timeoutAcquires = 0
        var timeoutReleases = 0
        let timeoutController = SleepInhibitionController(acquire: {
            timeoutAcquires += 1
            return 90
        }, release: { _ in timeoutReleases += 1 })
        timeoutController.update(input())
        timeoutController.update(.init(enabled: true, batteryAvailable: true, externalConnected: true,
                                       percentage: 70, target: 80, startedAt: nil,
                                       now: now.addingTimeInterval(28_801)))
        precondition(timeoutController.status == .timedOut && timeoutAcquires == 1 && timeoutReleases == 1)
        timeoutController.update(.init(enabled: true, batteryAvailable: true, externalConnected: true,
                                       percentage: 70, target: 80, startedAt: nil,
                                       now: now.addingTimeInterval(28_802)))
        precondition(timeoutController.status == .timedOut && timeoutAcquires == 1,
                     "timeout must stay latched while the same charge condition remains")
        timeoutController.update(input(external: false))
        timeoutController.update(input())
        precondition(timeoutAcquires == 2,
                     "unplug resets the timeout latch for a later charging session")

        var scheduledAction: (() -> Void)?
        var scheduledReleases: [UInt32] = []
        var timeoutCancellationCount = 0
        let scheduledController = SleepInhibitionController(acquire: { 120 }, release: { scheduledReleases.append($0) },
            scheduleTimeout: { delay, action in
                precondition(delay == SleepInhibitionPolicy.maximumDuration)
                scheduledAction = action
                return { timeoutCancellationCount += 1 }
            })
        scheduledController.update(input())
        precondition(scheduledController.isActive && scheduledAction != nil)
        scheduledAction?()
        precondition(scheduledController.status == .timedOut && !scheduledController.isActive)
        precondition(scheduledReleases == [120] && timeoutCancellationCount == 1,
                     "independent safety timer must release even without a new battery sample")
        scheduledController.update(input())
        precondition(scheduledReleases == [120] && !scheduledController.isActive,
                     "timer timeout must remain latched until the charge condition resets")

        let failing = SleepInhibitionController(acquire: { throw SleepAssertionError.creationFailed(7) }, release: { _ in })
        failing.update(input())
        precondition(failing.status == .failed("Uyku engeli oluşturulamadı (7).") && !failing.isActive)

        print("Sleep behavior: policy, single assertion, release and failure assertions passed; no live assertion.")
    }
}
