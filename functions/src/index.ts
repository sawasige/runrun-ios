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
      data: {
        type: "friend_request",
        requestId: snap.id,
      },
      apns: {
        payload: {
          aps: {
            alert: {
              title: "Friend Request",
              body: `${fromDisplayName} sent you a friend request`,
              titleLocKey: "FRIEND_REQUEST_TITLE",
              locKey: "FRIEND_REQUEST_BODY",
              locArgs: [fromDisplayName],
            },
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
 * フレンドリクエスト更新時に通知を送信
 * - 承認時: 送信者に通知
 * - 再申請時（createdAt更新）: 受信者に通知
 */
export const onFriendRequestUpdated = functions
  .region("asia-northeast1")
  .firestore.document("friendRequests/{requestId}")
  .onUpdate(async (change) => {
    const before = change.before.data() as FriendRequest;
    const after = change.after.data() as FriendRequest;

    // ケース1: ステータスがacceptedに変更された場合
    if (before.status !== "accepted" && after.status === "accepted") {
      await sendAcceptedNotification(after, change.after.id);
      return;
    }

    // ケース2: 再申請（createdAtが更新され、statusがpendingのまま）
    const beforeTime = before.createdAt?.toMillis() || 0;
    const afterTime = after.createdAt?.toMillis() || 0;
    if (after.status === "pending" && afterTime > beforeTime) {
      await sendResendNotification(after, change.after.id);
      return;
    }
  });

/**
 * フレンドリクエスト承認通知を送信
 */
async function sendAcceptedNotification(request: FriendRequest, requestId: string) {
  const fromUserId = request.fromUserId;
  const toUserId = request.toUserId;

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

  const message: admin.messaging.Message = {
    token: fcmToken,
    data: {
      type: "friend_accepted",
      userId: toUserId,
    },
    apns: {
      payload: {
        aps: {
          alert: {
            title: "Friend Accepted",
            body: `${accepterName} accepted your friend request`,
            titleLocKey: "FRIEND_ACCEPTED_TITLE",
            locKey: "FRIEND_ACCEPTED_BODY",
            locArgs: [accepterName],
          },
          sound: "default",
          badge: 1,
        },
      },
    },
  };

  try {
    await admin.messaging().send(message);
    console.log(`Accepted notification sent to ${fromUserId}`);
  } catch (error) {
    console.error(`Error sending notification to ${fromUserId}:`, error);
  }
}

/**
 * フレンドリクエスト再申請通知を送信
 */
async function sendResendNotification(request: FriendRequest, requestId: string) {
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

  const message: admin.messaging.Message = {
    token: fcmToken,
    data: {
      type: "friend_request",
      requestId: requestId,
    },
    apns: {
      payload: {
        aps: {
          alert: {
            title: "Friend Request",
            body: `${fromDisplayName} sent you a friend request`,
            titleLocKey: "FRIEND_REQUEST_TITLE",
            locKey: "FRIEND_REQUEST_BODY",
            locArgs: [fromDisplayName],
          },
          sound: "default",
          badge: 1,
        },
      },
    },
  };

  try {
    await admin.messaging().send(message);
    console.log(`Resend notification sent to ${toUserId}`);
  } catch (error) {
    console.error(`Error sending notification to ${toUserId}:`, error);
  }
}

/**
 * ユーザー削除時にデータをクリーンアップ
 */
export const onUserDeleted = functions
  .region("asia-northeast1")
  .auth.user()
  .onDelete(async (user) => {
    const userId = user.uid;
    console.log(`Cleaning up data for deleted user: ${userId}`);

    const batch = db.batch();

    try {
      // 1. フレンドリクエスト削除（送信したもの）
      const sentRequests = await db
        .collection("friendRequests")
        .where("fromUserId", "==", userId)
        .get();
      sentRequests.docs.forEach((doc) => batch.delete(doc.ref));
      console.log(`Deleting ${sentRequests.size} sent friend requests`);

      // 2. フレンドリクエスト削除（受信したもの）
      const receivedRequests = await db
        .collection("friendRequests")
        .where("toUserId", "==", userId)
        .get();
      receivedRequests.docs.forEach((doc) => batch.delete(doc.ref));
      console.log(`Deleting ${receivedRequests.size} received friend requests`);

      // 3. ラン記録削除
      const runs = await db
        .collection("runs")
        .where("userId", "==", userId)
        .get();
      runs.docs.forEach((doc) => batch.delete(doc.ref));
      console.log(`Deleting ${runs.size} run records`);

      // 4. フレンドのリストから自分を削除
      const userDoc = await db.collection("users").doc(userId).get();
      if (userDoc.exists) {
        // 自分のフレンドリストを取得
        const friends = await db
          .collection("users")
          .doc(userId)
          .collection("friends")
          .get();

        // 各フレンドのリストから自分を削除
        for (const friendDoc of friends.docs) {
          const friendId = friendDoc.id;
          const friendRef = db
            .collection("users")
            .doc(friendId)
            .collection("friends")
            .doc(userId);
          batch.delete(friendRef);
        }
        console.log(`Removing user from ${friends.size} friends' lists`);

        // 自分のフレンドリストを削除
        friends.docs.forEach((doc) => batch.delete(doc.ref));
      }

      // 5. ユーザープロフィール削除
      batch.delete(db.collection("users").doc(userId));

      // バッチ実行
      await batch.commit();
      console.log(`Successfully cleaned up data for user: ${userId}`);

      // 6. Storageのアバター画像削除
      try {
        const bucket = admin.storage().bucket();
        await bucket.deleteFiles({
          prefix: `avatars/${userId}/`,
        });
        console.log(`Deleted avatar images for user: ${userId}`);
      } catch (storageError) {
        console.log(`No avatar images to delete or error: ${storageError}`);
      }
    } catch (error) {
      console.error(`Error cleaning up user data: ${error}`);
      throw error;
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
      data: {
        type: "test",
      },
      apns: {
        payload: {
          aps: {
            alert: {
              title: "Test Notification",
              body: "Push notifications are working!",
              titleLocKey: "TEST_NOTIFICATION_TITLE",
              locKey: "TEST_NOTIFICATION_BODY",
            },
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
