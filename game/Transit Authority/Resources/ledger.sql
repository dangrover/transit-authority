

CREATE TABLE "ledger" (
"time" INTEGER NOT NULL,
"key" TEXT NOT NULL,
"subkey" TEXT,
"value" REAL NOT NULL,
"multiplier" INTEGER NOT NULL,
"period" INTEGER NOT NULL
);


CREATE INDEX "key_time_idx" ON "ledger" ("time","key", "subkey);