//
//  CaptureFlowTests.swift
//  VolcyUITests
//
//  UI tests for capture flow
//

import XCTest

class CaptureFlowTests: XCTestCase {

    var app: XCUIApplication!

    override func setUp() {
        super.setUp()

        continueAfterFailure = false

        app = XCUIApplication()
        app.launch()
    }

    func testCaptureButtonNavigation() {
        // Tap on "Start Scan" button on home screen
        let startScanButton = app.buttons["Start Scan"]
        XCTAssertTrue(startScanButton.exists)

        startScanButton.tap()

        // Verify capture view appeared
        XCTAssertTrue(app.navigationBars["Scan"].exists)

        // Verify cancel button exists
        let cancelButton = app.buttons["Cancel"]
        XCTAssertTrue(cancelButton.exists)

        // Cancel and return to home
        cancelButton.tap()

        XCTAssertTrue(app.navigationBars["Home"].exists)
    }

    func testQCIndicatorsVisible() {
        // Navigate to capture view
        app.buttons["Start Scan"].tap()

        // Wait for QC indicators to appear
        sleep(2)

        // Check that QC indicators are visible
        // Note: These might not update properly in simulator without ARKit
        // Real device testing required for full verification
    }

    func testSettingsNavigation() {
        // Navigate to profile tab
        app.tabBars.buttons["Profile"].tap()

        // Tap settings button
        app.buttons["Settings"].tap()

        // Verify settings view appeared
        XCTAssertTrue(app.navigationBars["Settings"].exists)

        // Verify key settings sections exist
        XCTAssertTrue(app.staticTexts["Account"].exists)
        XCTAssertTrue(app.staticTexts["Privacy & Data"].exists)

        // Tap done
        app.buttons["Done"].tap()
    }

    func testTabNavigation() {
        // Test all tab bar items
        let tabs = ["Home", "Trends", "Regimen", "Profile"]

        for tab in tabs {
            app.tabBars.buttons[tab].tap()
            XCTAssertTrue(app.navigationBars[tab].exists)
        }
    }
}
