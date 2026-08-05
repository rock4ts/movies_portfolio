import csv
import json
import random
import statistics
import string
import time
import uuid
from collections import defaultdict
from uuid import UUID

import psycopg
from pymongo import MongoClient


def get_random_user_ids(pg_conn: psycopg.Connection, amount: int = 1000):
    with pg_conn.cursor() as cur:
        cur.execute(f"SELECT * FROM app_user ORDER BY RANDOM() LIMIT {amount}")
        return [user[0] for user in cur.fetchall()]


def test_user_likes_pg(user_ids: list[UUID], pg_conn: psycopg.Connection, n_iterations: int = 1000):
    times = []
    with pg_conn.cursor() as cur:
        for i in range(n_iterations):
            user_id = user_ids[i]
            start = time.perf_counter()
            cur.execute(f"SELECT movie_id FROM movie_like WHERE user_id = '{user_id}'")
            cur.fetchall()
            end = time.perf_counter()
            times.append(end - start)
    return times


def test_user_likes_mongo(
    user_ids: list[UUID], mongo_client: MongoClient, n_iterations: int = 1000
):
    times = []
    collection = mongo_client["ugc"]["movie_like"]
    for i in range(n_iterations):
        user_id = user_ids[i]
        start = time.perf_counter()
        list(collection.find({"user_id": user_id}, {"movie_id": 1}))
        end = time.perf_counter()
        times.append(end - start)
    return times


def get_random_movie_ids(pg_conn: psycopg.Connection, amount: int = 1000):
    with pg_conn.cursor() as cur:
        cur.execute(f"SELECT id FROM movie ORDER BY RANDOM() LIMIT {amount}")
        return [row[0] for row in cur.fetchall()]


def test_movie_likes_dislikes_pg(
    movie_ids: list[UUID], pg_conn: psycopg.Connection, n_iterations: int = 1000
):
    times = []
    with pg_conn.cursor() as cur:
        for i in range(n_iterations):
            movie_id = movie_ids[i]
            start = time.perf_counter()
            cur.execute(
                f"""
                SELECT
                    COUNT(*) FILTER (WHERE value = 1) AS likes,
                    COUNT(*) FILTER (WHERE value = -1) AS dislikes
                FROM movie_like
                WHERE movie_id = '{movie_id}'
                """
            )
            cur.fetchone()
            end = time.perf_counter()
            times.append(end - start)
    return times


def test_movie_likes_dislikes_mongo(
    movie_ids: list[UUID], mongo_client: MongoClient, n_iterations: int = 1000
):
    times = []
    collection = mongo_client["ugc"]["movie_like"]
    for i in range(n_iterations):
        movie_id = movie_ids[i]
        start = time.perf_counter()
        pipeline = [
            {"$match": {"movie_id": movie_id}},
            {
                "$group": {
                    "_id": "$movie_id",
                    "likes": {"$sum": {"$cond": [{"$eq": ["$value", 1]}, 1, 0]}},
                    "dislikes": {"$sum": {"$cond": [{"$eq": ["$value", -1]}, 1, 0]}},
                }
            },
        ]
        list(collection.aggregate(pipeline))
        end = time.perf_counter()
        times.append(end - start)
    return times


def test_user_bookmarks_pg(
    user_ids: list[UUID], pg_conn: psycopg.Connection, n_iterations: int = 1000
):
    times = []
    with pg_conn.cursor() as cur:
        for i in range(n_iterations):
            user_id = user_ids[i]
            start = time.perf_counter()
            cur.execute(f"SELECT movie_id FROM bookmark WHERE user_id = '{user_id}'")
            cur.fetchall()
            end = time.perf_counter()
            times.append(end - start)
    return times


def test_user_bookmarks_mongo(
    user_ids: list[UUID], mongo_client: MongoClient, n_iterations: int = 1000
):
    times = []
    collection = mongo_client["ugc"]["bookmark"]
    for i in range(n_iterations):
        user_id = user_ids[i]
        start = time.perf_counter()
        list(collection.find({"user_id": user_id}))
        end = time.perf_counter()
        times.append(end - start)
    return times


def test_avg_rating_pg(
    movie_ids: list[UUID], pg_conn: psycopg.Connection, n_iterations: int = 1000
):
    times = []
    with pg_conn.cursor() as cur:
        for i in range(n_iterations):
            movie_id = movie_ids[i]
            start = time.perf_counter()
            cur.execute(
                f"SELECT AVG(value) FROM review_mark WHERE review_id IN "
                f"(SELECT id FROM review WHERE movie_id = '{movie_id}')"
            )
            cur.fetchone()
            end = time.perf_counter()
            times.append(end - start)
    return times


def test_avg_rating_mongo(
    movie_ids: list[UUID], mongo_client: MongoClient, n_iterations: int = 1000
):
    times = []
    review_col = mongo_client["ugc"]["review"]
    review_mark_col = mongo_client["ugc"]["review_mark"]

    for i in range(n_iterations):
        movie_id = movie_ids[i]
        start = time.perf_counter()
        review_ids = list(review_col.find({"movie_id": movie_id}, {"_id": 1}))
        review_ids = [r["_id"] for r in review_ids]
        if review_ids:
            pipeline = [
                {"$match": {"review_id": {"$in": review_ids}}},
                {"$group": {"_id": None, "avg_rating": {"$avg": "$value"}}},
            ]
            list(review_mark_col.aggregate(pipeline))
        end = time.perf_counter()
        times.append(end - start)
    return times


def test_like_write_visibility_pg(conn: psycopg.Connection, n_iterations: int = 1000):
    times = []

    with conn.cursor() as cur:
        new_movie_title = "".join(random.choices(string.ascii_letters + string.digits, k=15))
        cur.execute("INSERT INTO movie (title) VALUES (%s)", (new_movie_title,))
        conn.commit()
        cur.execute("SELECT id FROM movie WHERE title = %s", (new_movie_title,))
        new_movie_id = cur.fetchone()[0]

        for _ in range(n_iterations):
            new_user_id = str(uuid.uuid4())
            start = time.perf_counter()
            cur.execute(
                "INSERT INTO movie_like (value, user_id, movie_id) VALUES (%s, %s, %s)",
                (10, new_user_id, new_movie_id),
            )
            conn.commit()
            cur.execute("SELECT * FROM movie_like WHERE user_id = %s", (new_user_id,))
            cur.fetchone()
            end = time.perf_counter()
            times.append(end - start)
        cur.execute("DELETE FROM movie WHERE id = %s", (new_movie_id,))
        conn.commit()

    return times


def test_like_write_visibility_mongo(mongo_client: MongoClient, n_iterations: int = 1000):
    times = []
    ugc_db = mongo_client["ugc"]
    movie_like_collection = ugc_db.movie_like

    new_movie_id = uuid.uuid4()
    for _ in range(n_iterations):
        new_user_id = uuid.uuid4()
        doc = {
            "_id": str(uuid.uuid4()),
            "value": 10,
            "user_id": new_user_id,
            "movie_id": new_movie_id,
        }

        start = time.perf_counter()
        movie_like_collection.insert_one(doc)
        movie_like_collection.find_one({"user_id": new_user_id})
        end = time.perf_counter()
        times.append(end - start)

    movie_like_collection.delete_many({"movie_id": new_movie_id})

    return times


def record_stats(results_dict, test_name, system_name, times):
    stats = {"min": min(times), "median": statistics.median(times), "max": max(times)}
    results_dict[test_name][system_name] = stats


def save_results(filename, system, times):
    with open(filename, mode="a", newline="") as f:
        writer = csv.writer(f)
        writer.writerow(
            [system, f"{min(times):.6f}", f"{statistics.mean(times):.6f}", f"{max(times):.6f}"]
        )


if __name__ == "__main__":
    PG_USERS_DSN = "postgresql://testuser:testpass@localhost:5432/testdb"
    PG_UGC_DSN = "postgresql://testuser:testpass@localhost:5433/testdb"
    MONGO_UGC_DSN = "mongodb://localhost:27017/"

    # Кол-во повторений запроса
    N_ITERATIONS = 1000

    results: defaultdict = defaultdict(dict)

    with (
        psycopg.connect(PG_USERS_DSN) as users_conn,
        psycopg.connect(PG_UGC_DSN) as ugc_conn,
        MongoClient(MONGO_UGC_DSN, uuidRepresentation="standard") as mongo_client,
    ):
        random_user_ids = get_random_user_ids(users_conn, 1000)

        pg_user_likes_times = test_user_likes_pg(random_user_ids, ugc_conn, N_ITERATIONS)
        mongo_user_likes_times = test_user_likes_mongo(random_user_ids, mongo_client, N_ITERATIONS)
        record_stats(results, "user_likes", "pg", pg_user_likes_times)
        record_stats(results, "user_likes", "mongo", mongo_user_likes_times)

        random_movie_ids = get_random_movie_ids(ugc_conn)
        pg_movie_likes_times = test_movie_likes_dislikes_pg(
            random_movie_ids, ugc_conn, N_ITERATIONS
        )
        mongo_movie_likes_times = test_user_likes_mongo(
            random_movie_ids, mongo_client, N_ITERATIONS
        )
        record_stats(results, "movie_likes", "pg", pg_movie_likes_times)
        record_stats(results, "movie_likes", "mongo", mongo_movie_likes_times)

        pg_bookmarks_times = test_user_bookmarks_pg(random_user_ids, ugc_conn, N_ITERATIONS)
        mongo_bookmarks_times = test_user_bookmarks_mongo(
            random_user_ids, mongo_client, N_ITERATIONS
        )
        record_stats(results, "user_bookmarks", "pg", pg_bookmarks_times)
        record_stats(results, "user_bookmarks", "mongo", mongo_bookmarks_times)

        pg_avg_rating_results = test_avg_rating_pg(random_movie_ids, ugc_conn, N_ITERATIONS)
        mongo_avg_rating_results = test_avg_rating_mongo(
            random_movie_ids, mongo_client, N_ITERATIONS
        )
        record_stats(results, "avg_rating_calc", "pg", pg_avg_rating_results)
        record_stats(results, "avg_rating_calc", "mongo", mongo_avg_rating_results)

        pg_write_visibility_results = test_like_write_visibility_pg(ugc_conn, N_ITERATIONS)
        mongo_write_visibility_results = test_like_write_visibility_mongo(
            mongo_client, N_ITERATIONS
        )
        record_stats(results, "write_visibility", "pg", pg_write_visibility_results)
        record_stats(results, "write_visibility", "mongo", mongo_write_visibility_results)

        with open("load_testing_results.json", "w") as f:
            json.dump(results, f, indent=4)
