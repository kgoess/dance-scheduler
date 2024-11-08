CREATE TABLE role_pairs (
    role_pair_id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    role_pair VARCHAR(191) NOT NULL,
    is_deleted BOOLEAN NOT NULL DEFAULT 0,
    created_ts DATETIME NOT NULL,
    modified_ts TIMESTAMP NOT NULL,
    UNIQUE INDEX role_pair_idx(role_pair)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
