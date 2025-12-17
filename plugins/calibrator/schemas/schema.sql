-- Calibrator SQLite Schema v1.0
-- Requires SQLite 3.24.0+ for UPSERT (ON CONFLICT DO UPDATE) support

-- Observations table: Individual mismatch records
CREATE TABLE IF NOT EXISTS observations (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  timestamp   DATETIME DEFAULT CURRENT_TIMESTAMP,
  category    TEXT NOT NULL CHECK(category IN ('missing', 'excess', 'style', 'other')),
  situation   TEXT NOT NULL CHECK(length(situation) <= 500),
  expectation TEXT NOT NULL CHECK(length(expectation) <= 1000),
  file_path   TEXT,
  notes       TEXT
);

-- Patterns table: Aggregated patterns for skill promotion
CREATE TABLE IF NOT EXISTS patterns (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  situation   TEXT NOT NULL CHECK(length(situation) <= 500),
  instruction TEXT NOT NULL CHECK(length(instruction) <= 2000),
  count       INTEGER DEFAULT 1 CHECK(count >= 1),
  first_seen  DATETIME DEFAULT CURRENT_TIMESTAMP,
  last_seen   DATETIME DEFAULT CURRENT_TIMESTAMP,
  promoted    BOOLEAN DEFAULT FALSE,
  skill_path  TEXT,
  UNIQUE(situation, instruction)
);

-- Schema version tracking
CREATE TABLE IF NOT EXISTS schema_version (
  version    TEXT PRIMARY KEY,
  applied_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- Insert current schema version
INSERT OR IGNORE INTO schema_version (version) VALUES ('1.0');

-- Performance indexes
CREATE INDEX IF NOT EXISTS idx_observations_situation ON observations(situation);
CREATE INDEX IF NOT EXISTS idx_observations_timestamp ON observations(timestamp DESC);
CREATE INDEX IF NOT EXISTS idx_patterns_count ON patterns(count DESC);
CREATE INDEX IF NOT EXISTS idx_patterns_promoted ON patterns(promoted);

-- Composite index for UPSERT conflict detection (critical for performance)
CREATE INDEX IF NOT EXISTS idx_patterns_situation_instruction ON patterns(situation, instruction);
