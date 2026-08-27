from __future__ import annotations

import sqlite3
from contextlib import contextmanager
from pathlib import Path

SCHEMA_VERSION = 1

SCHEMA = """
CREATE TABLE IF NOT EXISTS schema_migrations(version INTEGER PRIMARY KEY, applied_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP);
CREATE TABLE IF NOT EXISTS users(
  id TEXT PRIMARY KEY, email TEXT NOT NULL UNIQUE COLLATE NOCASE, password_hash TEXT NOT NULL,
  display_name TEXT NOT NULL, created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE TABLE IF NOT EXISTS sessions(
  token_hash TEXT PRIMARY KEY, user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  expires_at TEXT NOT NULL, created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE TABLE IF NOT EXISTS goals(
  user_id TEXT PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  calories INTEGER NOT NULL CHECK(calories BETWEEN 800 AND 10000), protein REAL NOT NULL,
  carbs REAL NOT NULL, fat REAL NOT NULL, fiber REAL NOT NULL, updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE TABLE IF NOT EXISTS foods(
  id TEXT PRIMARY KEY, owner_user_id TEXT REFERENCES users(id) ON DELETE CASCADE,
  name TEXT NOT NULL, detail TEXT NOT NULL, emoji TEXT NOT NULL, calories INTEGER NOT NULL CHECK(calories >= 0),
  protein REAL NOT NULL, carbs REAL NOT NULL, fat REAL NOT NULL, fiber REAL NOT NULL,
  is_verified INTEGER NOT NULL DEFAULT 0, created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE TABLE IF NOT EXISTS food_entries(
  id TEXT PRIMARY KEY, user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  food_id TEXT NOT NULL REFERENCES foods(id), meal TEXT NOT NULL CHECK(meal IN ('Breakfast','Lunch','Dinner','Snack')),
  servings REAL NOT NULL CHECK(servings > 0 AND servings <= 20), logged_at TEXT NOT NULL,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS food_entries_user_date ON food_entries(user_id, logged_at);
CREATE TABLE IF NOT EXISTS habitat_state(
  user_id TEXT PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  xp INTEGER NOT NULL DEFAULT 0 CHECK(xp >= 0), level INTEGER NOT NULL DEFAULT 1 CHECK(level >= 1),
  unlocked_friends TEXT NOT NULL DEFAULT '["ollie"]', updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE TABLE IF NOT EXISTS weights(
  id TEXT PRIMARY KEY, user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  kilograms REAL NOT NULL CHECK(kilograms BETWEEN 20 AND 500), recorded_at TEXT NOT NULL
);
"""


class Database:
    def __init__(self, path: str | Path):
        self.path = str(path)
        self.initialize()

    def connect(self) -> sqlite3.Connection:
        connection = sqlite3.connect(self.path, check_same_thread=False)
        connection.row_factory = sqlite3.Row
        connection.execute("PRAGMA foreign_keys=ON")
        connection.execute("PRAGMA journal_mode=WAL")
        return connection

    def initialize(self) -> None:
        with self.connect() as connection:
            connection.executescript(SCHEMA)
            connection.execute("INSERT OR IGNORE INTO schema_migrations(version) VALUES (?)", (SCHEMA_VERSION,))
            self._seed_foods(connection)

    @contextmanager
    def transaction(self):
        connection = self.connect()
        try:
            connection.execute("BEGIN IMMEDIATE")
            yield connection
            connection.commit()
        except Exception:
            connection.rollback()
            raise
        finally:
            connection.close()

    @staticmethod
    def _seed_foods(connection: sqlite3.Connection) -> None:
        foods = [
            ("greek-yogurt", "Greek yogurt", "170 g", "🥛", 100, 17, 6, 0, 0),
            ("blueberries", "Blueberries", "½ cup", "🫐", 42, .5, 11, .2, 1.8),
            ("oatmeal", "Oatmeal", "½ cup dry (40 g)", "🥣", 150, 5, 27, 3, 4),
            ("banana", "Banana", "1 medium", "🍌", 105, 1.3, 27, .4, 3.1),
            ("almonds", "Almonds", "1 oz (23 g)", "🥜", 160, 6, 6, 14, 3.5),
        ]
        connection.executemany("""INSERT OR IGNORE INTO foods(id,name,detail,emoji,calories,protein,carbs,fat,fiber,is_verified)
          VALUES(?,?,?,?,?,?,?,?,?,1)""", foods)
