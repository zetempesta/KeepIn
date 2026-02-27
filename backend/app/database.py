from collections.abc import Iterable
from contextlib import contextmanager
from datetime import datetime, timezone
import hashlib
from uuid import UUID

import psycopg
from psycopg.rows import dict_row

from .config import settings
from .schemas import LabelPayload, NotePayload, RegisterPayload, to_db_color


class DatabaseRepository:
    def __init__(self, dsn: str) -> None:
        self._dsn = dsn

    @contextmanager
    def _connection(self) -> Iterable[psycopg.Connection]:
        with psycopg.connect(self._dsn, row_factory=dict_row) as connection:
            yield connection


class NotesRepository(DatabaseRepository):
    def _ensure_labels(
        self,
        cursor: psycopg.Cursor,
        labels: list[str],
        owner_username: str,
    ) -> None:
        if not labels:
            return

        for label in labels:
            cursor.execute(
                """
                INSERT INTO labels (owner_username, name)
                VALUES (%s, %s)
                ON CONFLICT (owner_username, name) DO NOTHING;
                """,
                (owner_username, label),
            )

    def fetch_all(self, owner_username: str) -> list[dict]:
        with self._connection() as connection, connection.cursor() as cursor:
            cursor.execute(
                """
                SELECT id, title, content, background_color, labels, is_pinned, created_at, updated_at
                FROM notes
                WHERE owner_username = %s
                ORDER BY is_pinned DESC, updated_at DESC;
                """,
                (owner_username,),
            )
            return list(cursor.fetchall())

    def create(self, payload: NotePayload, owner_username: str) -> dict:
        now = datetime.now(timezone.utc)
        with self._connection() as connection, connection.cursor() as cursor:
            cursor.execute(
                """
                INSERT INTO notes (
                    owner_username,
                    title,
                    content,
                    background_color,
                    labels,
                    is_pinned,
                    created_at,
                    updated_at
                ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
                RETURNING id, title, content, background_color, labels, is_pinned, created_at, updated_at;
                """,
                (
                    owner_username,
                    payload.title.strip(),
                    payload.content.strip(),
                    to_db_color(payload.background_color),
                    payload.normalized_labels,
                    payload.is_pinned,
                    now,
                    now,
                ),
            )
            record = cursor.fetchone()
            self._ensure_labels(cursor, payload.normalized_labels, owner_username)
            return record

    def update(
        self,
        note_id: UUID,
        payload: NotePayload,
        owner_username: str,
    ) -> dict | None:
        now = datetime.now(timezone.utc)
        with self._connection() as connection, connection.cursor() as cursor:
            cursor.execute(
                """
                UPDATE notes
                SET
                    title = %s,
                    content = %s,
                    background_color = %s,
                    labels = %s,
                    is_pinned = %s,
                    updated_at = %s
                WHERE id = %s AND owner_username = %s
                RETURNING id, title, content, background_color, labels, is_pinned, created_at, updated_at;
                """,
                (
                    payload.title.strip(),
                    payload.content.strip(),
                    to_db_color(payload.background_color),
                    payload.normalized_labels,
                    payload.is_pinned,
                    now,
                    note_id,
                    owner_username,
                ),
            )
            record = cursor.fetchone()
            self._ensure_labels(cursor, payload.normalized_labels, owner_username)
            return record

    def delete(self, note_id: UUID, owner_username: str) -> bool:
        with self._connection() as connection, connection.cursor() as cursor:
            cursor.execute(
                "DELETE FROM notes WHERE id = %s AND owner_username = %s;",
                (note_id, owner_username),
            )
            return cursor.rowcount > 0


class LabelsRepository(DatabaseRepository):
    def exists(self, label_name: str, owner_username: str) -> bool:
        with self._connection() as connection, connection.cursor() as cursor:
            cursor.execute(
                """
                SELECT EXISTS(
                           SELECT 1
                           FROM labels
                           WHERE owner_username = %s AND name = %s
                       ) AS has_label,
                       EXISTS(
                           SELECT 1
                           FROM notes
                           WHERE owner_username = %s AND %s = ANY(labels)
                       ) AS has_note_label;
                """,
                (owner_username, label_name, owner_username, label_name),
            )
            record = cursor.fetchone()
            return bool(record["has_label"] or record["has_note_label"])

    def fetch_all(self, owner_username: str) -> list[dict]:
        with self._connection() as connection, connection.cursor() as cursor:
            cursor.execute(
                """
                SELECT name
                FROM (
                    SELECT name
                    FROM labels
                    WHERE owner_username = %s
                    UNION
                    SELECT DISTINCT UNNEST(labels) AS name
                    FROM notes
                    WHERE owner_username = %s
                ) AS all_labels
                WHERE name IS NOT NULL AND BTRIM(name) <> ''
                ORDER BY name ASC;
                """,
                (owner_username, owner_username),
            )
            return list(cursor.fetchall())

    def create(self, payload: LabelPayload, owner_username: str) -> dict | None:
        normalized = payload.normalized_name
        if not normalized:
            return None

        with self._connection() as connection, connection.cursor() as cursor:
            cursor.execute(
                """
                INSERT INTO labels (owner_username, name)
                VALUES (%s, %s)
                ON CONFLICT (owner_username, name) DO UPDATE SET name = EXCLUDED.name
                RETURNING name;
                """,
                (owner_username, normalized),
            )
            return cursor.fetchone()

    def rename(
        self,
        current_name: str,
        new_name: str,
        owner_username: str,
    ) -> dict | None:
        normalized_current = current_name.strip()
        normalized_new = new_name.strip()
        if not normalized_current or not normalized_new:
            return None

        if normalized_current == normalized_new:
            return (
                {"name": normalized_new}
                if self.exists(normalized_current, owner_username)
                else None
            )

        if not self.exists(normalized_current, owner_username):
            return None

        with self._connection() as connection, connection.cursor() as cursor:
            cursor.execute(
                """
                INSERT INTO labels (owner_username, name)
                VALUES (%s, %s)
                ON CONFLICT (owner_username, name) DO NOTHING;
                """,
                (owner_username, normalized_new),
            )
            cursor.execute(
                """
                UPDATE notes
                SET labels = COALESCE(
                    (
                        SELECT ARRAY(
                            SELECT DISTINCT item
                            FROM UNNEST(ARRAY_REPLACE(notes.labels, %s, %s)) AS item
                            WHERE BTRIM(item) <> ''
                            ORDER BY item
                        )
                    ),
                    '{}'
                )
                WHERE owner_username = %s AND %s = ANY(labels);
                """,
                (
                    normalized_current,
                    normalized_new,
                    owner_username,
                    normalized_current,
                ),
            )
            cursor.execute(
                "DELETE FROM labels WHERE owner_username = %s AND name = %s;",
                (owner_username, normalized_current),
            )
            return {"name": normalized_new}

    def delete(self, label_name: str, owner_username: str) -> bool:
        normalized = label_name.strip()
        if not normalized:
            return False

        if not self.exists(normalized, owner_username):
            return False

        with self._connection() as connection, connection.cursor() as cursor:
            cursor.execute(
                """
                UPDATE notes
                SET labels = ARRAY_REMOVE(labels, %s)
                WHERE owner_username = %s AND %s = ANY(labels);
                """,
                (normalized, owner_username, normalized),
            )
            cursor.execute(
                "DELETE FROM labels WHERE owner_username = %s AND name = %s;",
                (owner_username, normalized),
            )
            return True


notes_repository = NotesRepository(settings.database_dsn)
labels_repository = LabelsRepository(settings.database_dsn)


def _hash_password(password: str) -> str:
    return hashlib.sha256(password.encode("utf-8")).hexdigest()


class UsersRepository(DatabaseRepository):
    def authenticate(self, username: str, password: str) -> dict | None:
        normalized_username = username.strip()
        if not normalized_username or not password:
            return None

        with self._connection() as connection, connection.cursor() as cursor:
            cursor.execute(
                """
                SELECT username, password_hash
                FROM users
                WHERE username = %s;
                """,
                (normalized_username,),
            )
            record = cursor.fetchone()

        if record is None:
            return None

        if record["password_hash"] != _hash_password(password):
            return None

        return {"username": record["username"]}

    def create(self, payload: RegisterPayload) -> dict | None:
        normalized_username = payload.normalized_username
        if not normalized_username or not payload.password:
            return None

        with self._connection() as connection, connection.cursor() as cursor:
            cursor.execute(
                """
                INSERT INTO users (username, password_hash)
                VALUES (%s, %s)
                ON CONFLICT (username) DO NOTHING
                RETURNING username;
                """,
                (normalized_username, _hash_password(payload.password)),
            )
            return cursor.fetchone()


users_repository = UsersRepository(settings.database_dsn)
