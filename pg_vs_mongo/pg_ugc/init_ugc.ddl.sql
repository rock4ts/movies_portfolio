CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

CREATE TABLE IF NOT EXISTS movie (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    title TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS movie_title_idx ON movie (title);


CREATE TABLE IF NOT EXISTS movie_like (
    id BIGSERIAL PRIMARY KEY,
    value SMALLINT NOT NULL,
    user_id TEXT NOT NULL,
    movie_id UUID NOT NULL REFERENCES movie(id) ON DELETE CASCADE,
    UNIQUE (user_id, movie_id)
);

CREATE INDEX IF NOT EXISTS idx_movie_like_user_id ON movie_like (user_id);
CREATE INDEX IF NOT EXISTS idx_movie_like_movie_id ON movie_like (movie_id);


CREATE TABLE IF NOT EXISTS bookmark (
    id BIGSERIAL PRIMARY KEY,
    user_id TEXT NOT NULL,
    movie_id UUID NOT NULL REFERENCES movie(id) ON DELETE CASCADE,
    UNIQUE (user_id, movie_id)
);

CREATE INDEX IF NOT EXISTS idx_bookmark_user_id ON bookmark (user_id);
CREATE INDEX IF NOT EXISTS idx_bookmark_movie_id ON bookmark (movie_id);


CREATE TABLE IF NOT EXISTS review (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    text TEXT NOT NULL,
    user_id TEXT NOT NULL,
    movie_id UUID NOT NULL REFERENCES movie(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_review_user_id ON review (user_id);
CREATE INDEX IF NOT EXISTS idx_review_movie_id ON review (movie_id);


CREATE TABLE IF NOT EXISTS review_mark (
    id BIGSERIAL PRIMARY KEY,
    value SMALLINT NOT NULL CHECK (value IN (-1, 1)),
    user_id TEXT NOT NULL,
    review_id UUID NOT NULL REFERENCES review(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_review_mark_user_id ON review_mark (user_id);
CREATE INDEX IF NOT EXISTS idx_review_mark_review_id ON review_mark (review_id);
