ALTER TABLE notes
ADD COLUMN IF NOT EXISTS owner_username TEXT NOT NULL DEFAULT 'zetempesta';

ALTER TABLE notes
DROP CONSTRAINT IF EXISTS notes_owner_username_fkey;

ALTER TABLE notes
ADD CONSTRAINT notes_owner_username_fkey
FOREIGN KEY (owner_username) REFERENCES users (username) ON DELETE CASCADE;

CREATE INDEX IF NOT EXISTS idx_notes_owner_pinned_updated_at
  ON notes (owner_username, is_pinned DESC, updated_at DESC);

ALTER TABLE labels
ADD COLUMN IF NOT EXISTS owner_username TEXT NOT NULL DEFAULT 'zetempesta';

ALTER TABLE labels
DROP CONSTRAINT IF EXISTS labels_owner_username_fkey;

ALTER TABLE labels
ADD CONSTRAINT labels_owner_username_fkey
FOREIGN KEY (owner_username) REFERENCES users (username) ON DELETE CASCADE;

ALTER TABLE labels
DROP CONSTRAINT IF EXISTS labels_pkey;

ALTER TABLE labels
ADD CONSTRAINT labels_pkey PRIMARY KEY (owner_username, name);

CREATE INDEX IF NOT EXISTS idx_labels_owner_name
  ON labels (owner_username, name);
