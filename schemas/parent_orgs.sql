CREATE TABLE parent_orgs (
    parent_org_id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    full_name VARCHAR(255) NOT NULL,
    url VARCHAR(255),
    photo_url VARCHAR(255),
    abbreviation VARCHAR(255) NOT NULL,
    is_deleted BOOLEAN NOT NULL DEFAULT 0,
    created_ts DATETIME NOT NULL,
    modified_ts TIMESTAMP NOT NULL,

    UNIQUE INDEX parent_org_id_idx(full_name),
    UNIQUE INDEX abbreviation_idx(abbreviation)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
