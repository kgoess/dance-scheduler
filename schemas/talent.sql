CREATE TABLE talent (
    talent_id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    url VARCHAR(255),
    photo_url VARCHAR(255),
    is_deleted BOOLEAN NOT NULL DEFAULT 0,
    created_ts DATETIME NOT NULL,
    modified_ts TIMESTAMP NOT NULL,

    UNIQUE INDEX talent_name_idx(name)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
