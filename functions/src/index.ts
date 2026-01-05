import * as functions from "firebase-functions";
import * as admin from "firebase-admin";

admin.initializeApp();

const db = admin.firestore();

interface FriendRequest {
  fromUserId: string;
  fromDisplayName: string;
  toUserId: string;
  status: string;
  createdAt: admin.firestore.Timestamp;
}

interface UserProfile {
  displayName?: string;
  fcmToken?: string;
}

/**
 * フレンドリクエスト作成時に通知を送信
 */
export const onFriendRequestCreated = functions
  .region("asia-northeast1")
  .firestore.document("friendRequests/{requestId}")
  .onCreate(async (snap) => {
    const request = snap.data() as FriendRequest;
    const toUserId = request.toUserId;
    const fromDisplayName = request.fromDisplayName;

    // 受信者のFCMトークンを取得
    const userDoc = await db.collection("users").doc(toUserId).get();
    if (!userDoc.exists) {
      console.log(`User ${toUserId} not found`);
      return;
    }

    const userData = userDoc.data() as UserProfile;
    const fcmToken = userData.fcmToken;

    if (!fcmToken) {
      console.log(`User ${toUserId} has no FCM token`);
      return;
    }

    // 通知を送信
    const message: admin.messaging.Message = {
      token: fcmToken,
      notification: {
        title: "フレンドリクエスト",
        body: `${fromDisplayName}さんからフレンドリクエストが届きました`,
      },
      data: {
        type: "friend_request",
        requestId: snap.id,
      },
      apns: {
        payload: {
          aps: {
            sound: "default",
            badge: 1,
          },
        },
      },
    };

    try {
      await admin.messaging().send(message);
      console.log(`Notification sent to ${toUserId}`);
    } catch (error) {
      console.error(`Error sending notification to ${toUserId}:`, error);
    }
  });

/**
 * フレンドリクエスト承認時に通知を送信
 */
export const onFriendRequestAccepted = functions
  .region("asia-northeast1")
  .firestore.document("friendRequests/{requestId}")
  .onUpdate(async (change) => {
    const before = change.before.data() as FriendRequest;
    const after = change.after.data() as FriendRequest;

    // ステータスがacceptedに変更された場合のみ処理
    if (before.status === "accepted" || after.status !== "accepted") {
      return;
    }

    const fromUserId = after.fromUserId;
    const toUserId = after.toUserId;

    // 承認者の表示名を取得
    const accepterDoc = await db.collection("users").doc(toUserId).get();
    const accepterData = accepterDoc.data() as UserProfile | undefined;
    const accepterName = accepterData?.displayName || "ユーザー";

    // 送信者のFCMトークンを取得
    const senderDoc = await db.collection("users").doc(fromUserId).get();
    if (!senderDoc.exists) {
      console.log(`User ${fromUserId} not found`);
      return;
    }

    const senderData = senderDoc.data() as UserProfile;
    const fcmToken = senderData.fcmToken;

    if (!fcmToken) {
      console.log(`User ${fromUserId} has no FCM token`);
      return;
    }

    // 通知を送信
    const message: admin.messaging.Message = {
      token: fcmToken,
      notification: {
        title: "フレンド承認",
        body: `${accepterName}さんがフレンドリクエストを承認しました`,
      },
      data: {
        type: "friend_accepted",
        userId: toUserId,
      },
      apns: {
        payload: {
          aps: {
            sound: "default",
            badge: 1,
          },
        },
      },
    };

    try {
      await admin.messaging().send(message);
      console.log(`Notification sent to ${fromUserId}`);
    } catch (error) {
      console.error(`Error sending notification to ${fromUserId}:`, error);
    }
  });

/**
 * テスト用: 自分自身に通知を送信
 */
export const sendTestNotification = functions
  .region("asia-northeast1")
  .https.onCall(async (data, context) => {
    // 認証チェック
    if (!context.auth) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "認証が必要です"
      );
    }

    const userId = context.auth.uid;

    // ユーザーのFCMトークンを取得
    const userDoc = await db.collection("users").doc(userId).get();
    if (!userDoc.exists) {
      throw new functions.https.HttpsError("not-found", "ユーザーが見つかりません");
    }

    const userData = userDoc.data() as UserProfile;
    const fcmToken = userData.fcmToken;

    if (!fcmToken) {
      throw new functions.https.HttpsError(
        "failed-precondition",
        "FCMトークンが登録されていません"
      );
    }

    // テスト通知を送信
    const message: admin.messaging.Message = {
      token: fcmToken,
      notification: {
        title: "テスト通知",
        body: "プッシュ通知が正常に動作しています！",
      },
      data: {
        type: "test",
      },
      apns: {
        payload: {
          aps: {
            sound: "default",
          },
        },
      },
    };

    try {
      await admin.messaging().send(message);
      return { success: true, message: "通知を送信しました" };
    } catch (error) {
      console.error("Error sending test notification:", error);
      throw new functions.https.HttpsError("internal", "通知の送信に失敗しました");
    }
  });
