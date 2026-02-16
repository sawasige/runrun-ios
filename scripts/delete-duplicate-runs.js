/**
 * Firestoreの重複ランレコードを削除するワンショットスクリプト
 *
 * 同じルール: タイムスタンプ60秒以内 + 距離0.1km以内 → 同一ラン → 最初の1件だけ残す
 *
 * 使い方:
 *   全ユーザーの重複状況を確認（削除なし）:
 *     node scripts/delete-duplicate-runs.js --dry-run
 *
 *   全ユーザーの重複を削除:
 *     node scripts/delete-duplicate-runs.js
 */

const admin = require("firebase-admin");

// Firebase Admin初期化（デフォルト認証情報を使用）
admin.initializeApp({ projectId: "runrun-66f12" });
const db = admin.firestore();

const DRY_RUN = process.argv.includes("--dry-run");

function findDuplicates(runs) {
  const seen = [];
  const duplicateIds = [];
  for (const run of runs) {
    const isNew = !seen.some(
      (existing) =>
        Math.abs(existing.date.getTime() - run.date.getTime()) < 60000 &&
        Math.abs(existing.distanceKm - run.distanceKm) < 0.1
    );
    if (isNew) {
      seen.push(run);
    } else {
      duplicateIds.push(run.id);
    }
  }
  return { uniqueCount: seen.length, duplicateIds };
}

async function main() {
  // 1. 全ユーザーを取得
  const usersSnapshot = await db.collection("users").get();
  console.log(`全ユーザー数: ${usersSnapshot.size}\n`);

  let totalDuplicates = 0;
  const usersWithDuplicates = [];

  // 2. ユーザーごとに重複を検出
  for (const userDoc of usersSnapshot.docs) {
    const userId = userDoc.id;
    const displayName = userDoc.data().displayName || "(名前なし)";

    const runsSnapshot = await db
      .collection("runs")
      .where("userId", "==", userId)
      .get();

    if (runsSnapshot.empty) continue;

    const runs = runsSnapshot.docs.map((doc) => ({
      id: doc.id,
      date: doc.data().date.toDate(),
      distanceKm: doc.data().distanceKm,
    }));

    const { uniqueCount, duplicateIds } = findDuplicates(runs);

    if (duplicateIds.length > 0) {
      console.log(
        `${displayName}: 全${runs.length}件 → ユニーク${uniqueCount}件, 重複${duplicateIds.length}件`
      );
      usersWithDuplicates.push({ userId, displayName, duplicateIds, uniqueCount });
      totalDuplicates += duplicateIds.length;
    } else {
      console.log(`${displayName}: ${runs.length}件 (重複なし)`);
    }
  }

  console.log(`\n--- 合計 ---`);
  console.log(`重複のあるユーザー: ${usersWithDuplicates.length}人`);
  console.log(`重複レコード合計: ${totalDuplicates}件`);

  if (totalDuplicates === 0) {
    console.log("重複なし。終了します。");
    process.exit(0);
  }

  if (DRY_RUN) {
    console.log("\n[dry-run] 削除はスキップしました。");
    process.exit(0);
  }

  // 3. WriteBatchで500件ずつ削除
  console.log("\n削除を開始します...");
  const BATCH_LIMIT = 500;
  let totalDeleted = 0;

  for (const { displayName, duplicateIds } of usersWithDuplicates) {
    let deleted = 0;
    for (let i = 0; i < duplicateIds.length; i += BATCH_LIMIT) {
      const batch = db.batch();
      const chunk = duplicateIds.slice(i, i + BATCH_LIMIT);
      for (const id of chunk) {
        batch.delete(db.collection("runs").doc(id));
      }
      await batch.commit();
      deleted += chunk.length;
    }
    totalDeleted += deleted;
    console.log(`${displayName}: ${deleted}件削除`);
  }

  console.log(`\n完了: 合計${totalDeleted}件削除`);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
