import Foundation
import ServiceManagement

@MainActor
private final class LoginFixture {
    enum Failure: Error { case refused }
    var status: SMAppService.Status = .notRegistered
    var registrationResult: SMAppService.Status = .enabled
    var unregistrationResult: SMAppService.Status = .notRegistered
    var registerError = false
    var unregisterError = false
    var registrations = 0
    var unregistrations = 0
    var settingsOpens = 0

    func model(path: String = "/Applications/Catecho.app") -> RadioLoginItem {
        RadioLoginItem(
            bundleURL: URL(fileURLWithPath: path),
            homeDirectory: URL(fileURLWithPath: "/Users/fixture"),
            readStatus: { self.status },
            register: {
                self.registrations += 1
                if self.registerError { throw Failure.refused }
                self.status = self.registrationResult
            },
            unregister: {
                self.unregistrations += 1
                if self.unregisterError { throw Failure.refused }
                self.status = self.unregistrationResult
            },
            openSettings: { self.settingsOpens += 1 }
        )
    }
}

@main
private struct LoginTests {
    @MainActor static func main() {
        var failures = 0
        var checks = 0
        func check(_ condition: Bool, _ label: String) {
            checks += 1
            if condition { print("PASS \(label)") }
            else { print("FAIL \(label)"); failures += 1 }
        }

        let enabled = LoginFixture()
        enabled.status = .enabled
        let enabledModel = enabled.model()
        check(enabledModel.state == .on && enabledModel.isRequested, "initial enabled status comes from macOS")
        check(enabled.registrations == 0 && enabled.unregistrations == 0, "initialization does not change login registration")
        enabledModel.setEnabled(true)
        check(enabled.registrations == 0, "already enabled request is idempotent")
        enabledModel.setEnabled(false)
        check(enabledModel.state == .off && !enabledModel.isRequested && enabled.unregistrations == 1, "disabling reports confirmed OS status")
        enabledModel.setEnabled(false)
        check(enabled.unregistrations == 1, "already disabled request is idempotent")

        let pending = LoginFixture()
        pending.status = .requiresApproval
        let pendingModel = pending.model()
        check(pendingModel.state == .approvalRequired && pendingModel.isRequested, "pending approval is never reported as enabled")
        pendingModel.setEnabled(true)
        check(pending.registrations == 0 && pendingModel.state == .approvalRequired, "pending approval does not repeatedly register")
        pendingModel.openSettings()
        check(pending.settingsOpens == 1, "settings action opens the login-items destination")
        pending.status = .enabled
        pendingModel.refresh()
        check(pendingModel.state == .on, "refresh observes approval made outside the app")
        pending.status = .requiresApproval
        pendingModel.setEnabled(false)
        check(pendingModel.state == .off && pending.unregistrations == 1, "an unapproved request can be withdrawn")

        let fresh = LoginFixture()
        let freshModel = fresh.model()
        freshModel.setEnabled(true)
        check(freshModel.state == .on && freshModel.errorKey == nil && fresh.registrations == 1, "successful registration rechecks OS state")

        let newPending = LoginFixture()
        newPending.registrationResult = .requiresApproval
        let newPendingModel = newPending.model()
        newPendingModel.setEnabled(true)
        check(newPendingModel.state == .approvalRequired && newPendingModel.errorKey == nil, "registration requiring approval stays pending")

        let refused = LoginFixture()
        refused.registrationResult = .notRegistered
        let refusedModel = refused.model()
        refusedModel.setEnabled(true)
        check(refusedModel.state == .off && refusedModel.errorKey == "Could not enable start at login. Try again in System Settings.", "a request with no OS change is not presented as success")
        refused.registrationResult = .enabled
        refusedModel.setEnabled(true)
        check(refusedModel.state == .on && refusedModel.errorKey == nil, "successful retry clears the previous error")

        let registerError = LoginFixture()
        registerError.registerError = true
        let registerErrorModel = registerError.model()
        registerErrorModel.setEnabled(true)
        check(registerErrorModel.state == .off && registerErrorModel.errorKey != nil, "registration error preserves truthful off state")

        let unregisterError = LoginFixture()
        unregisterError.status = .enabled
        unregisterError.unregisterError = true
        let unregisterErrorModel = unregisterError.model()
        unregisterErrorModel.setEnabled(false)
        check(unregisterErrorModel.state == .on && unregisterErrorModel.errorKey == "Could not disable start at login. Try again in System Settings.", "unregistration error preserves truthful enabled state")

        let disableRefused = LoginFixture()
        disableRefused.status = .enabled
        disableRefused.unregistrationResult = .enabled
        let disableRefusedModel = disableRefused.model()
        disableRefusedModel.setEnabled(false)
        check(disableRefusedModel.state == .on && disableRefusedModel.errorKey != nil, "unconfirmed disabling is reported as a failure")

        for path in ["/Applications/Catecho.app", "/Users/fixture/Applications/Catecho.app"] {
            let fixture = LoginFixture()
            let model = fixture.model(path: path)
            model.setEnabled(true)
            check(model.canChange && fixture.registrations == 1 && model.state == .on, "installed app is eligible: \(path)")
        }
        for path in ["/Users/fixture/Downloads/Catecho.app", "/Applications/Folder/Catecho.app", "/Applications/Catecho", "/Volumes/Catecho/Catecho.app"] {
            let fixture = LoginFixture()
            let model = fixture.model(path: path)
            model.setEnabled(true)
            check(!model.canChange && fixture.registrations == 0 && model.state == .off && model.errorKey == "Move Catecho to Applications before enabling start at login.", "uninstalled app cannot register: \(path)")
        }

        let moved = LoginFixture()
        moved.status = .enabled
        let movedModel = moved.model(path: "/Users/fixture/Downloads/Catecho.app")
        check(movedModel.state == .on && movedModel.canChange, "moved app can read and withdraw an existing registration")
        movedModel.setEnabled(false)
        check(moved.unregistrations == 1 && movedModel.state == .off, "installation restriction does not prevent disabling")

        for status in [SMAppService.Status.notFound, SMAppService.Status(rawValue: 999)!] {
            let unavailable = LoginFixture()
            unavailable.status = status
            let unavailableModel = unavailable.model()
            check(unavailableModel.state == .unavailable && !unavailableModel.canChange && !unavailableModel.isRequested, "missing or unknown OS status is unavailable")
            unavailableModel.setEnabled(true)
            check(unavailable.registrations == 0 && unavailableModel.errorKey == "Start at login is unavailable on this Mac.", "unavailable service is not registered optimistically")
        }
        print("\(checks - failures)/\(checks) login checks passed")
        if failures > 0 { exit(1) }
    }
}
