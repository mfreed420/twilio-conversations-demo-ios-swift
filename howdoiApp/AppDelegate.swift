//
//  AppDelegate.swift
//  howdoiApp
//
//  Copyright © Twilio, Inc. All rights reserved.
//

import UIKit
import UserNotifications
import Firebase
import AppCenter
import AppCenterAnalytics
import AppCenterDistribute

class AppDelegate: UIResponder, UIApplicationDelegate {

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
#if !DEBUG
        FirebaseApp.configure()
        AppCenter.start(withAppSecret: "APPCENTER_SECRET", services: [Distribute.self, Analytics.self])
#endif

        UNUserNotificationCenter.current().delegate = self
        registerForAPNSNotifications()
        registerDefaultsFromSettingsBundle()

        return true
    }

    func registerForPushNotifications() {
      UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { [weak self] granted, error in
          NSLog("Permission granted: \(granted)")
          guard granted else { return }
          self?.registerForAPNSNotifications()
      }
    }

    func registerForAPNSNotifications() {
      UNUserNotificationCenter.current().getNotificationSettings { (settings) in
        if settings.authorizationStatus == .authorized {
          DispatchQueue.main.async {
            UIApplication.shared.registerForRemoteNotifications()
          }
        } else {
            self.registerForPushNotifications()
        }
      }
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        NSLog("Received device push token")
        AppModel.shared.deviceToken = deviceToken
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        NSLog("Failed to get push token, error: \(error)")
        AppModel.shared.deviceToken = nil
    }

    private func registerDefaultsFromSettingsBundle() {
        guard let settingsUrl = Bundle.main.url(forResource: "Settings", withExtension: "bundle")?.appendingPathComponent("Root.plist"),
              let settingsPlist = NSDictionary(contentsOf: settingsUrl),
              let preferences = settingsPlist["PreferenceSpecifiers"] as? [[String: Any]] else {
            return
        }

        var defaultsToRegister: [String: Any] = [:]

        for preference in preferences {
            guard let key = preference["Key"] as? String else {
                continue
            }
            defaultsToRegister[key] = preference["DefaultValue"]
        }
        NSLog("\(defaultsToRegister)")
        UserDefaults.standard.register(defaults: defaultsToRegister)
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension AppDelegate: UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        // User tapped the notification
        let userInfo = response.notification.request.content.userInfo
        
        howdoiApp.navigationHelper.currentTab = Tab.conversations

        if let messageType = userInfo["twi_message_type"] as? String {
            switch messageType {
            case "twilio.conversations.new_message", "twilio.conversation.added_to_conversation":
                if let conversationSid = userInfo["conversation_sid"] as? String {
                    howdoiApp.navigationHelper.currentScreen = "MessageList-\(conversationSid)"
                }
            case "twilio.conversations.removed_from_conversation":
                howdoiApp.navigationHelper.currentScreen = nil
            default:
                NSLog("Not supported message type \(messageType)")
            }
        }

        if let conversationsClient = AppModel.shared.client.conversationsClient {
           conversationsClient.handleNotification(userInfo) { result in
               if !result.isSuccessful {
                   print("Handling of notification was not successful")
               }
           }
       }
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // Notification arrived while the app is in the foreground.
        // Make sure the user is notified.
        completionHandler([.list, .badge, .sound])
    }
}
