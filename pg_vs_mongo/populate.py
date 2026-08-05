import random
import string

import psycopg
from pymongo import MongoClient


def random_string(length=12):
    return "".join(random.choices(string.ascii_letters + string.digits, k=length))


def insert_pg_users(conn: psycopg.Connection):
    EXPECTED_COUNT = 100_000
    BATCH_SIZE = 10_000
    print("Inserting users...")
    with conn.cursor() as cur:
        cur.execute("TRUNCATE app_user CASCADE")
        for i in range(0, EXPECTED_COUNT, BATCH_SIZE):
            batch = [(random_string(10),) for _ in range(min(BATCH_SIZE, EXPECTED_COUNT - i))]
            cur.executemany("INSERT INTO app_user (username) VALUES (%s)", batch)
        conn.commit()

    with conn.cursor() as cur:
        db_inserted_count = cur.execute("SELECT count(id) FROM app_user").fetchone()[0]
        assert db_inserted_count == EXPECTED_COUNT


def insert_pg_movies(conn: psycopg.Connection):
    EXPECTED_COUNT = 10_000
    BATCH_SIZE = 10_000
    print("Inserting movies...")
    with conn.cursor() as cur:
        cur.execute("TRUNCATE movie CASCADE")
        for i in range(0, EXPECTED_COUNT, BATCH_SIZE):
            batch = [(random_string(15),) for _ in range(min(BATCH_SIZE, EXPECTED_COUNT - i))]
            cur.executemany("INSERT INTO movie (title) VALUES (%s)", batch)
        conn.commit()

    with conn.cursor() as cur:
        db_inserted_count = cur.execute("SELECT count(id) FROM movie").fetchone()[0]
        assert db_inserted_count == EXPECTED_COUNT


def pg_ids_iterator(conn: psycopg.Connection, table_name, batch_size: int):
    with conn.cursor() as cur:
        cur.execute(f"SELECT id FROM {table_name}")
        while batch := cur.fetchmany(batch_size):
            yield [item[0] for item in batch]


def insert_pg_likes(
    users_conn: psycopg.Connection,
    ugc_conn: psycopg.Connection,
):
    EXPECTED_COUNT = 10_000_000
    BATCH_SIZE = 10_000
    LIKES_LIMIT_PER_USER = 100
    print("Inserting likes...")
    likes = []
    total_inserted = 0

    with ugc_conn.cursor() as cur:
        cur.execute("TRUNCATE movie_like")
        ugc_conn.commit()

    user_ids_iterator = pg_ids_iterator(users_conn, "app_user", BATCH_SIZE)
    movie_ids = next(pg_ids_iterator(ugc_conn, "movie", 10000))
    current_round = 0

    while True:
        try:
            user_ids = next(user_ids_iterator)
        except StopIteration:
            current_round += 1
            if current_round >= LIKES_LIMIT_PER_USER:
                break
            else:
                user_ids_iterator = pg_ids_iterator(users_conn, "app_user", BATCH_SIZE)
                continue

        for i, u_id in enumerate(user_ids):
            m_id = movie_ids[(i + current_round * LIKES_LIMIT_PER_USER) % 10000]
            if current_round % 2 == 0:
                likes.append((10, u_id, m_id))
            else:
                likes.append((0, u_id, m_id))

        with ugc_conn.cursor() as cur:
            cur.executemany(
                "INSERT INTO movie_like (value, user_id, movie_id) VALUES (%s, %s, %s)", likes
            )
            ugc_conn.commit()
        total_inserted += len(likes)
        likes = []
        print(f"Totally inserted {total_inserted} likes")

    with ugc_conn.cursor() as cur:
        db_inserted_count = cur.execute("SELECT count(id) FROM movie_like").fetchone()[0]
        assert db_inserted_count == EXPECTED_COUNT


def insert_pg_reviews(users_conn: psycopg.Connection, ugc_conn: psycopg.Connection):
    EXPECTED_COUNT = 100_000
    print("Inserting reviews...")
    reviews = []
    total_inserted = 0

    with ugc_conn.cursor() as cur:
        cur.execute("TRUNCATE review CASCADE")
        ugc_conn.commit()

    movie_ids = next(pg_ids_iterator(ugc_conn, "movie", 10000))
    user_ids_iterator = pg_ids_iterator(users_conn, "app_user", 10000)
    exhausted = False
    while not exhausted:
        try:
            user_ids = next(user_ids_iterator)
        except StopIteration:
            exhausted = True
            continue

        for u_id, m_id in zip(user_ids, movie_ids):
            reviews.append((random_string(100), u_id, m_id))

        with ugc_conn.cursor() as cur:
            cur.executemany(
                "INSERT INTO review (text, user_id, movie_id) VALUES (%s, %s, %s)",
                reviews,
            )
            ugc_conn.commit()

        total_inserted += len(reviews)
        reviews = []
        print(f"Totally inserted {total_inserted} reviews")
    with ugc_conn.cursor() as cur:
        db_inserted_count = cur.execute("SELECT count(id) FROM review").fetchone()[0]
        assert db_inserted_count == EXPECTED_COUNT


def insert_pg_review_marks(
    users_conn: psycopg.Connection,
    ugc_conn: psycopg.Connection,
):
    BATCH_SIZE = 10000
    EXPECTED_COUNT = 1_000_000
    # Каждый юзер может поставить 10 оценок, каждое ревью может собрать 10 оценок
    MARK_LIMIT = 10
    review_marks = []
    total_inserted = 0
    print("Inserting review marks...")
    with ugc_conn.cursor() as cur:
        cur.execute("TRUNCATE review_mark")
        ugc_conn.commit()
    # В базах одинаковое кол-во юзеров и ревью
    review_ids_iterator = pg_ids_iterator(ugc_conn, "review", BATCH_SIZE)
    user_ids_iterator = pg_ids_iterator(users_conn, "app_user", BATCH_SIZE)

    current_round = 0
    while True:
        try:
            user_ids = next(user_ids_iterator)
            review_ids = next(review_ids_iterator)
        except StopIteration:
            current_round += 1
            if current_round >= MARK_LIMIT:
                break
            else:
                review_ids_iterator = pg_ids_iterator(ugc_conn, "review", BATCH_SIZE)
                user_ids_iterator = pg_ids_iterator(users_conn, "app_user", BATCH_SIZE)
                continue

        for i, r_id in enumerate(review_ids):
            u_id = user_ids[(i + current_round * 1000) % 10000]
            if current_round % 2 == 0:
                review_marks.append((1, u_id, r_id))
            else:
                review_marks.append((-1, u_id, r_id))

        with ugc_conn.cursor() as cur:
            cur.executemany(
                "INSERT INTO review_mark (value, user_id, review_id) VALUES (%s, %s, %s)",
                review_marks,
            )
            ugc_conn.commit()

        total_inserted += len(review_marks)
        review_marks = []
        print(f"Totally inserted {total_inserted} review marks")

    with ugc_conn.cursor() as cur:
        db_inserted_count = cur.execute("SELECT count(id) FROM review_mark").fetchone()[0]
        assert db_inserted_count == EXPECTED_COUNT


def insert_pg_bookmarks(users_conn: psycopg.Connection, ugc_conn: psycopg.Connection):
    EXPECTED_COUNT = 1_000_000
    bookmarks = []
    total_inserted = 0

    print("Inserting bookmarks...")
    with ugc_conn.cursor() as cur:
        cur.execute("TRUNCATE bookmark")
        ugc_conn.commit()

    user_ids_iterator = pg_ids_iterator(users_conn, "app_user", 10000)
    movie_ids = next(pg_ids_iterator(ugc_conn, "movie", 10000))

    current_round = 0
    while True:
        try:
            user_ids = next(user_ids_iterator)
        except StopIteration:
            current_round += 1
            if current_round >= 10:
                break
            else:
                user_ids_iterator = pg_ids_iterator(users_conn, "app_user", 10000)
                continue

        for i, u_id in enumerate(user_ids):
            bookmarks.append((u_id, movie_ids[(i + current_round * 1000) % 10000]))

        with ugc_conn.cursor() as cur:
            cur.executemany(
                "INSERT INTO bookmark (user_id, movie_id) VALUES (%s, %s)",
                bookmarks,
            )
            ugc_conn.commit()

        total_inserted += len(bookmarks)
        bookmarks = []
        print(f"Totally inserted {total_inserted} bookmarks")

    with ugc_conn.cursor() as cur:
        db_inserted_count = cur.execute("SELECT count(id) FROM bookmark").fetchone()[0]
        assert db_inserted_count == EXPECTED_COUNT


def pg_table_iterator(conn: psycopg.Connection, table_name, batch_size: int):
    with conn.cursor() as cur:
        cur.execute(f"SELECT * FROM {table_name}")
        yield [desc[0] for desc in cur.description]

        while batch := cur.fetchmany(batch_size):
            yield batch


def transfer_pg_tables_to_mongo(ugc_conn: psycopg.Connection, mongo_client: MongoClient):
    mongo_db = mongo_client["ugc"]
    tables = {
        "movie": mongo_db.movie,
        "movie_like": mongo_db.movie_like,
        "bookmark": mongo_db.bookmark,
        "review": mongo_db.review,
        "review_mark": mongo_db.review_mark,
    }
    for t_name in tables:
        print(f"Transfering '{t_name}' table.")
        tables[t_name].delete_many({})
        transfered_count = 0
        pg_table_iterr = pg_table_iterator(ugc_conn, t_name, 5000)
        columns = next(pg_table_iterr)
        columns[0] = "_id"
        exhausted = False
        while not exhausted:
            try:
                pg_rows = next(pg_table_iterr)
            except StopIteration:
                exhausted = True
                continue

            docs = [dict(zip(columns, row)) for row in pg_rows]
            tables[t_name].insert_many(docs)
            transfered_count += len(docs)
            if transfered_count % 10000 == 0:
                print(f"Transferred {transfered_count} documents to MongoDB '{t_name}' collection.")
        print(f"✅ '{t_name}' transfer complete.")


if __name__ == "__main__":
    PG_USERS_DSN = "postgresql://testuser:testpass@localhost:5432/testdb"
    PG_UGC_DSN = "postgresql://testuser:testpass@localhost:5433/testdb"
    MONGO_UGC_DSN = "mongodb://localhost:27017/"

    with (
        psycopg.connect(PG_USERS_DSN) as users_conn,
        psycopg.connect(PG_UGC_DSN) as ugc_conn,
        MongoClient(MONGO_UGC_DSN, uuidRepresentation="standard") as mongo_client,
    ):
        insert_pg_users(users_conn)
        print("✅ Postgres users population complete.")
        insert_pg_movies(ugc_conn)
        print("✅ Postgres movies population complete.")
        insert_pg_likes(users_conn, ugc_conn)
        print("✅ Postgres likes population complete.")
        insert_pg_reviews(users_conn, ugc_conn)
        print("✅ Postgres reviews population complete.")
        insert_pg_review_marks(users_conn, ugc_conn)
        print("✅ Postgres review marks population complete.")
        insert_pg_bookmarks(users_conn, ugc_conn)
        print("✅ Postgres bookmarks population complete.")
        transfer_pg_tables_to_mongo(ugc_conn, mongo_client)
        print("✅ Mongo ugc content transfer complete.")
