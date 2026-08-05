#!/bin/bash

set -e

echo "⏳ Creating collections and indexes..."
mongosh --host mongo_db:27017 <<'EOF'
use ugc;

db.createCollection("movie");
db.movie.createIndex({ title: 1 });

db.createCollection("movie_like");
db.movie_like.createIndex({ user_id: 1 });
db.movie_like.createIndex({ movie_id: 1 });
db.movie_like.createIndex({ user_id: 1, movie_id: 1 }, { unique: true });

db.createCollection("bookmark");
db.bookmark.createIndex({ user_id: 1 });
db.bookmark.createIndex({ movie_id: 1 });
db.bookmark.createIndex({ user_id: 1, movie_id: 1 }, { unique: true });

db.createCollection("review");
db.review.createIndex({ user_id: 1 });
db.review.createIndex({ movie_id: 1 });

db.createCollection("review_mark");
db.review_mark.createIndex({ user_id: 1 });
db.review_mark.createIndex({ review_id: 1 });
EOF

echo "✅ Collections and indexes created."
