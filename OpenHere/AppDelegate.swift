//
//  AppDelegate.swift
//  OpenHere
//
//  Created by Marc Schwieterman on 7/30/16.
//  Copyright © 2016 Marc Schwieterman. All rights reserved.
//

import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    @IBOutlet weak var window: NSWindow!
    @IBOutlet weak var browserPopUpButton: NSPopUpButton!
    @IBOutlet weak var setDefaultBrowserButton: NSButton!

    private let defaults = UserDefaults.standard
    private let browserManager = BrowserManager()

    private var isOpeningURL = false

    func applicationWillFinishLaunching(_ notification: Notification) {
        defaults.registerDefaultVales()
        NSAppleEventManager.shared().setEventHandler(
            self,
            andSelector: #selector(handleGetURLEvent(event:withReplyEvent:)),
            forEventClass: AEEventClass(kInternetEventClass),
            andEventID: AEEventID(kAEGetURL))
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard !isOpeningURL else { return }
        browserPopUpButton.autoenablesItems = false
        browserManager.browserDescriptions.forEach { browser in
            add(browser: browser, toPopUpButton: browserPopUpButton)
        }
        if !browserManager.isAccessibilityEnabled {
            waitForAccessibility()
        }
    }

    private var accessibilityBanner: AccessibilityBanner?
    private var replacedTopConstraints: [NSLayoutConstraint] = []

    // shows a banner above the controls until the user turns on Accessibility, checking once per second
    private func waitForAccessibility() {
        let contentView = window.contentView!
        let banner = AccessibilityBanner(target: self, action: #selector(openAccessibilitySettings))
        banner.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(banner)

        replacedTopConstraints = contentView.constraints.filter {
            $0.firstAttribute == .top && $0.secondItem === contentView && $0.secondAttribute == .top
        }
        NSLayoutConstraint.deactivate(replacedTopConstraints)
        NSLayoutConstraint.activate([
            banner.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            banner.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            banner.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20)
        ] + replacedTopConstraints.map {
            ($0.firstItem as! NSView).topAnchor.constraint(equalTo: banner.bottomAnchor, constant: 20)
        })
        accessibilityBanner = banner
        setControlsEnabled(false)
        fitWindowToContent()

        Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] timer in
            guard self?.browserManager.isAccessibilityEnabled == true else { return }
            timer.invalidate()
            self?.accessibilityGranted()
        }
    }

    private func accessibilityGranted() {
        accessibilityBanner?.showGranted()
        fitWindowToContent()
        setControlsEnabled(true)
        NSApp.activate(ignoringOtherApps: true)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            guard let self = self else { return }
            self.accessibilityBanner?.removeFromSuperview()
            self.accessibilityBanner = nil
            NSLayoutConstraint.activate(self.replacedTopConstraints)
            self.fitWindowToContent()
        }
    }

    private func setControlsEnabled(_ enabled: Bool) {
        browserPopUpButton.isEnabled = enabled
        setDefaultBrowserButton.isEnabled = enabled && !browserManager.isDefaultBrowser
    }

    private func fitWindowToContent() {
        let contentView = window.contentView!
        contentView.layoutSubtreeIfNeeded()
        let frame = window.frame
        let size = window.frameRect(forContentRect: NSRect(origin: .zero, size: NSSize(width: contentView.frame.width, height: contentView.fittingSize.height))).size
        // keep the top edge in place while the height changes
        window.setFrame(NSRect(x: frame.minX, y: frame.maxY - size.height, width: size.width, height: size.height), display: true, animate: window.isVisible)
    }

    @objc private func openAccessibilitySettings() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        defer { isOpeningURL = false }
        guard !isOpeningURL else { return }
        if browserManager.isDefaultBrowser {
            setDefaultBrowserButton.isEnabled = false
        }
        window.makeKeyAndOrderFront(self)
    }

    private func add(browser: BrowserDescription, toPopUpButton: NSPopUpButton) {
        let image = browser.image
        let height = browserPopUpButton.fittingSize.height
        image.size = NSSize(width: height, height: height)

        browserPopUpButton.addItem(withTitle: browser.isSupported ? browser.name : "\(browser.name) (not supported yet)")
        let item = browserPopUpButton.lastItem!
        item.image = image
        item.isEnabled = browser.isSupported

        if browser.isTargetBrowser {
            browserPopUpButton.select(item)
        }
    }

    @IBAction func browserPopUpButtonChanged(button: NSPopUpButton) {
        setTargetBrowserToSelectedBrowser()
    }

    @IBAction func setDefaultBrowser(_ sender: NSButton) {
        setDefaultBrowserButton.isEnabled = false
        browserManager.setDefaultBrowser()
        setTargetBrowserToSelectedBrowser()
    }

    private func setTargetBrowserToSelectedBrowser() {
        browserManager.setTargetBrowser(index: browserPopUpButton.indexOfSelectedItem)
    }

    @objc private func handleGetURLEvent(event: NSAppleEventDescriptor, withReplyEvent replyEvent: NSAppleEventDescriptor) {
        isOpeningURL = true
        if let urlAsString = event.paramDescriptor(forKeyword: keyDirectObject)?.stringValue {
            browserManager.openURL(url: urlAsString)
            guard browserManager.isAccessibilityEnabled else {
                // without Accessibility every link opens in a new window: stay open and show the banner
                isOpeningURL = false
                return
            }
            NSRunningApplication.current.terminate()
        }
    }

}

final class AccessibilityBanner: NSBox {

    private let icon = NSImageView()
    private let titleLabel = NSTextField(labelWithString: "Accessibility permission needed")
    private let details = NSStackView()

    init(target: AnyObject, action: Selector) {
        super.init(frame: .zero)
        boxType = .custom
        titlePosition = .noTitle
        borderWidth = 0
        cornerRadius = 10
        fillColor = NSColor.systemOrange.withAlphaComponent(0.15)

        icon.image = NSImage(systemSymbolName: "lock.shield.fill", accessibilityDescription: nil)
        icon.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 24, weight: .regular)
        icon.contentTintColor = .systemOrange

        titleLabel.font = .boldSystemFont(ofSize: NSFont.systemFontSize)

        let smallFont = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
        let message = NSTextField(wrappingLabelWithString: "OpenHere uses Accessibility to find browser windows in the current Space. Turn on OpenHere in System Settings › Privacy & Security › Accessibility. If OpenHere is not in the list, click + and add it from Applications.")
        message.font = smallFont
        message.textColor = .secondaryLabelColor
        message.preferredMaxLayoutWidth = 350

        let button = NSButton(title: "Open System Settings", target: target, action: action)
        button.keyEquivalent = "\r"
        let spinner = NSProgressIndicator()
        spinner.style = .spinning
        spinner.controlSize = .small
        spinner.startAnimation(nil)
        let waiting = NSTextField(labelWithString: "Waiting for permission…")
        waiting.font = smallFont
        waiting.textColor = .secondaryLabelColor

        let actions = NSStackView(views: [button, spinner, waiting])
        actions.spacing = 8
        details.setViews([message, actions], in: .leading)
        details.orientation = .vertical
        details.alignment = .leading
        details.spacing = 10

        let text = NSStackView(views: [titleLabel, details])
        text.orientation = .vertical
        text.alignment = .leading
        text.spacing = 4

        let row = NSStackView(views: [icon, text])
        row.alignment = .top
        row.spacing = 12
        row.translatesAutoresizingMaskIntoConstraints = false
        contentView!.addSubview(row)
        NSLayoutConstraint.activate([
            row.topAnchor.constraint(equalTo: contentView!.topAnchor, constant: 12),
            row.bottomAnchor.constraint(equalTo: contentView!.bottomAnchor, constant: -12),
            row.leadingAnchor.constraint(equalTo: contentView!.leadingAnchor, constant: 14),
            row.trailingAnchor.constraint(lessThanOrEqualTo: contentView!.trailingAnchor, constant: -14)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func showGranted() {
        icon.image = NSImage(systemSymbolName: "checkmark.circle.fill", accessibilityDescription: nil)
        icon.contentTintColor = .systemGreen
        titleLabel.stringValue = "Accessibility permission is on"
        details.isHidden = true
        fillColor = NSColor.systemGreen.withAlphaComponent(0.15)
    }

}
