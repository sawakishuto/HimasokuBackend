# インタラクティブ通知の実装ガイド

## サーバー側の設定 ✅

サーバー側では以下を実装済みです：

### 通知カテゴリ

- カテゴリ ID: `HIMASOKU_INVITE`
- 2 つのアクションボタン：
  - 「参加する」(`JOIN_ACTION`)
  - 「辞退する」(`DECLINE_ACTION`)

### API エンドポイント

#### 1. グループ通知送信

```bash
POST /notifications/group/:group_id
```

**リクエスト例：**

```json
{
  "name": "田中さん",
  "durationTime": 60
}
```

#### 2. 通知レスポンス処理

```bash
POST /notifications/response
```

**リクエスト例：**

```json
{
  "firebase_uid": "user_firebase_uid",
  "action_identifier": "JOIN_ACTION",
  "group_id": "group_123",
  "sender_name": "田中さん",
  "duration_time": 60
}
```

## iOS 側で必要な設定

### 1. 通知カテゴリとアクションの登録

AppDelegate.swift または SceneDelegate.swift で以下を追加：

```swift
import UserNotifications

func setupNotificationCategories() {
    // アクションの定義
    let joinAction = UNNotificationAction(
        identifier: "JOIN_ACTION",
        title: "参加する",
        options: [.foreground]
    )

    let declineAction = UNNotificationAction(
        identifier: "DECLINE_ACTION",
        title: "辞退する",
        options: []
    )

    // カテゴリの定義
    let inviteCategory = UNNotificationCategory(
        identifier: "HIMASOKU_INVITE",
        actions: [joinAction, declineAction],
        intentIdentifiers: [],
        options: [.customDismissAction]
    )

    // 通知センターにカテゴリを登録
    UNUserNotificationCenter.current().setNotificationCategories([inviteCategory])
}

// アプリ起動時に呼び出し
func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
    setupNotificationCategories()
    return true
}
```

### 2. 通知アクションの処理

UNUserNotificationCenterDelegate を実装：

```swift
extension AppDelegate: UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {

        let userInfo = response.notification.request.content.userInfo
        let actionIdentifier = response.actionIdentifier

        // 通知データから必要な情報を取得
        guard let groupId = userInfo["group_id"] as? String,
              let senderName = userInfo["sender_name"] as? String,
              let durationTime = userInfo["durationTime"] as? Int else {
            completionHandler()
            return
        }

        // Firebase認証からUID取得
        guard let firebaseUid = Auth.auth().currentUser?.uid else {
            completionHandler()
            return
        }

        // サーバーにアクションレスポンスを送信
        sendNotificationResponse(
            firebaseUid: firebaseUid,
            actionIdentifier: actionIdentifier,
            groupId: groupId,
            senderName: senderName,
            durationTime: durationTime
        )

        completionHandler()
    }
}
```

### 3. サーバーへのレスポンス送信

```swift
func sendNotificationResponse(firebaseUid: String, actionIdentifier: String, groupId: String, senderName: String, durationTime: Int) {
    let url = URL(string: "https://your-server.com/notifications/response")!
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")

    let payload = [
        "firebase_uid": firebaseUid,
        "action_identifier": actionIdentifier,
        "group_id": groupId,
        "sender_name": senderName,
        "duration_time": durationTime
    ]

    do {
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Error sending notification response: \(error)")
                return
            }
            print("Notification response sent successfully")
        }.resume()

    } catch {
        print("Error creating request: \(error)")
    }
}
```

## 通知の流れ

1. **送信者**がグループに暇を共有 → サーバーに POST
2. **サーバー**がグループメンバーにインタラクティブ通知を送信
3. **受信者**が通知の「参加する」または「辞退する」を選択
4. **iOS**アプリがサーバーにアクションレスポンスを送信
5. **サーバー**が参加/辞退の処理を実行
6. **サーバー**がグループの他のメンバーに結果を通知

## 注意事項

- インタラクティブ通知は iOS 10+ でサポート
- 本番環境では適切な APNS 証明書/キーファイルが必要
- 通知カテゴリは必ずアプリ起動時に登録すること
- アクションの処理は非同期で行い、UI の更新は適切に処理すること
