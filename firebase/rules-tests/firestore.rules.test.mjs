import { readFileSync } from "node:fs";
import {
  initializeTestEnvironment,
  assertSucceeds,
  assertFails,
} from "@firebase/rules-unit-testing";

const rules = readFileSync(new URL("../firestore.rules", import.meta.url), "utf8");

const testEnv = await initializeTestEnvironment({
  projectId: "payreview-rules-test",
  firestore: { rules },
});

async function run() {
  const userA = testEnv.authenticatedContext("userA").firestore();
  const userB = testEnv.authenticatedContext("userB").firestore();
  const anonymous = testEnv.unauthenticatedContext().firestore();

  const sampleTransaction = {
    amountMinorUnits: 1000,
    currencyCode: "TWD",
    occurredAt: new Date(),
    source: "manual",
    schemaVersion: 1,
    createdAt: new Date(),
    updatedAt: new Date(),
  };

  // A user can write their own transaction.
  await assertSucceeds(
    userA.doc("users/userA/transactions/tx1").set(sampleTransaction)
  );

  // A user can read their own transaction back.
  await assertSucceeds(userA.doc("users/userA/transactions/tx1").get());

  // A different signed-in user cannot read userA's transaction.
  await assertFails(userB.doc("users/userA/transactions/tx1").get());

  // A different signed-in user cannot write into userA's path.
  await assertFails(
    userB.doc("users/userA/transactions/tx2").set(sampleTransaction)
  );

  // An unauthenticated request is rejected entirely.
  await assertFails(anonymous.doc("users/userA/transactions/tx1").get());

  console.log("All Firestore rules checks passed.");
}

try {
  await run();
} finally {
  await testEnv.cleanup();
}
