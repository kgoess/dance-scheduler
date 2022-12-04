CREATE TABLE callers (
    caller_id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    url VARCHAR(255),
    photo_url VARCHAR(255),
    is_deleted BOOLEAN NOT NULL DEFAULT 0,
    created_ts DATETIME NOT NULL,
    modified_ts TIMESTAMP NOT NULL,

    UNIQUE INDEX caller_id_idx(name)
) ENGINE=InnoDB DEFAULT CHARACTER SET=utf8;
