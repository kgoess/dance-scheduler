CREATE TABLE board_agenda (
    board_agenda_id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    meeting_date    DATE NOT NULL,
    agenda_text     TEXT NOT NULL DEFAULT '',
    draft_minutes_url VARCHAR(512) NOT NULL DEFAULT '',
    created_ts      DATETIME NOT NULL,
    modified_ts     TIMESTAMP NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
