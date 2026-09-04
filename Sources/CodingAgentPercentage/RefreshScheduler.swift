import Foundation

@MainActor
final class RefreshScheduler {
    private var task: Task<Void, Never>?

    func start(interval: Duration = .seconds(300), action: @escaping @MainActor () async -> Void) {
        task?.cancel()
        task = Task {
            await action()
            while !Task.isCancelled {
                try? await Task.sleep(for: interval)
                guard !Task.isCancelled else { return }
                await action()
            }
        }
    }

    deinit { task?.cancel() }
}
