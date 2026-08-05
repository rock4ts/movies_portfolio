#!/bin/bash

set -e

echo "⏳ Creating collections and indexes..."
mongosh --host $MONGO_URL <<EOF

use $UGC_DB;

db.createCollection("$COLL_LIKES");
db.$COLL_LIKES.createIndex({ user_id: 1 });
db.$COLL_LIKES.createIndex({ movie_id: 1 });
db.$COLL_LIKES.createIndex({ user_id: 1, movie_id: 1 }, { unique: true });

db.createCollection("$COLL_BOOKMARKS");
db.$COLL_BOOKMARKS.createIndex({ user_id: 1 });
db.$COLL_BOOKMARKS.createIndex({ movie_id: 1 });
db.$COLL_BOOKMARKS.createIndex({ user_id: 1, movie_id: 1 }, { unique: true });

db.createCollection("$COLL_REVIEWS");
db.$COLL_REVIEWS.createIndex({ user_id: 1 });
db.$COLL_REVIEWS.createIndex({ movie_id: 1 });

use $NOTIFICATIONS_DB

db.createCollection("$COLL_EMAILS");
db.$COLL_EMAILS.createIndex({ delivered: 1 })
db.$COLL_EMAILS.createIndex(
  { delivered_at: 1 },
  { expireAfterSeconds: 86400 }
)
db.$COLL_EMAILS.createIndex({ delivered: 1, rendered_at: 1 })

EOF

echo "✅ Collections and indexes created."
