import UIKit

/// Presentation only. It does not connect to WebSocket or fetch data.
/// Call from the existing login-summary and WebSocket event flows.
@MainActor
final class ScreenEventPresentationCoordinator {
    private weak var hostViewController: UIViewController?
    private weak var summaryBanner: ScreenEventsSummaryBannerView?
    private weak var toastView: ScreenEventToastView?
    private var toastDismissWorkItem: DispatchWorkItem?
    private var currentSummary: ScreenEventsSummary?

    init(hostViewController: UIViewController) {
        self.hostViewController = hostViewController
    }

    func showSummary(_ summary: ScreenEventsSummary) {
        guard summary.totalCount > 0, let hostView = hostViewController?.view else { return }
        currentSummary = summary
        summaryBanner?.removeFromSuperview()

        let banner = ScreenEventsSummaryBannerView()
        banner.configure(with: summary)
        banner.alpha = 0
        banner.transform = CGAffineTransform(translationX: 0, y: -18)
        banner.onOpen = { [weak self] in self?.openSummaryDetails() }
        banner.onDismiss = { [weak self] in self?.dismissSummary() }
        banner.translatesAutoresizingMaskIntoConstraints = false
        hostView.addSubview(banner)
        NSLayoutConstraint.activate([
            banner.leadingAnchor.constraint(equalTo: hostView.safeAreaLayoutGuide.leadingAnchor, constant: 14),
            banner.trailingAnchor.constraint(equalTo: hostView.safeAreaLayoutGuide.trailingAnchor, constant: -14),
            banner.topAnchor.constraint(equalTo: hostView.safeAreaLayoutGuide.topAnchor, constant: 8)
        ])
        summaryBanner = banner
        UIView.animate(withDuration: 0.30, delay: 0, options: [.curveEaseOut]) {
            banner.alpha = 1
            banner.transform = .identity
        }
    }

    func showLiveEvent(_ event: ScreenEvent) {
        guard let hostView = hostViewController?.view else { return }
        toastDismissWorkItem?.cancel()
        toastView?.removeFromSuperview()

        let toast = ScreenEventToastView()
        toast.configure(with: event)
        toast.alpha = 0
        toast.transform = CGAffineTransform(translationX: 0, y: 24)
        toast.onSelect = { [weak self] in self?.openEvent(event) }
        toast.onDismiss = { [weak self] in self?.dismissToast() }
        toast.translatesAutoresizingMaskIntoConstraints = false
        hostView.addSubview(toast)
        NSLayoutConstraint.activate([
            toast.leadingAnchor.constraint(equalTo: hostView.safeAreaLayoutGuide.leadingAnchor, constant: 14),
            toast.trailingAnchor.constraint(equalTo: hostView.safeAreaLayoutGuide.trailingAnchor, constant: -14),
            toast.bottomAnchor.constraint(equalTo: hostView.safeAreaLayoutGuide.bottomAnchor, constant: -14)
        ])
        toastView = toast
        UIView.animate(withDuration: 0.30, delay: 0, options: [.curveEaseOut]) {
            toast.alpha = 1
            toast.transform = .identity
        }

        let work = DispatchWorkItem { [weak self, weak toast] in
            guard let self, let toast, self.toastView === toast else { return }
            self.dismissToast()
        }
        toastDismissWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 4, execute: work)
    }

    func dismissSummary() {
        guard let banner = summaryBanner else { return }
        UIView.animate(withDuration: 0.20, animations: {
            banner.alpha = 0
            banner.transform = CGAffineTransform(translationX: 0, y: -12)
        }, completion: { [weak self] _ in
            banner.removeFromSuperview()
            if self?.summaryBanner === banner { self?.summaryBanner = nil }
        })
    }

    func dismissToast() {
        toastDismissWorkItem?.cancel()
        toastDismissWorkItem = nil
        guard let toast = toastView else { return }
        UIView.animate(withDuration: 0.20, animations: {
            toast.alpha = 0
            toast.transform = CGAffineTransform(translationX: 0, y: 18)
        }, completion: { [weak self] _ in
            toast.removeFromSuperview()
            if self?.toastView === toast { self?.toastView = nil }
        })
    }

    private func openSummaryDetails() {
        guard let hostViewController, let currentSummary else { return }
        let detailVC = ScreenEventsViewController(summary: currentSummary)
        detailVC.onSelectEvent = { [weak self] event in self?.openEvent(event) }
        hostViewController.navigationController?.pushViewController(detailVC, animated: true)
    }

    private func openEvent(_ event: ScreenEvent) {
        // TODO: map to SwiftCinemas' real movie/screening navigation after inspecting it.
        // A deleted screening may no longer be navigable; handle that case gracefully.
        dismissToast()
        _ = event
    }
}
