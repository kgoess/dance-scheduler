CREATE TABLE programmers (
    programmer_id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    email VARCHAR(255) NOT NULL,
    password_hash VARCHAR(128),
    is_superuser BOOLEAN,
    is_deleted BOOLEAN NOT NULL DEFAULT 0,
    created_ts DATETIME NOT NULL,
    modified_ts TIMESTAMP NOT NULL,

    UNIQUE INDEX programmer_email_idx(email)
) ENGINE=InnoDB DEFAULT CHARACTER SET=utf8;
