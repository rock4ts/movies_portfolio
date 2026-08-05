CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

CREATE TABLE IF NOT EXISTS app_user (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    username TEXT NOT NULL
);

CREATE INDEX user_username_idx ON app_user (username);
