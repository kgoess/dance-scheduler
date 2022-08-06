CREATE TABLE programmers (
    programmer_id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    email VARCHAR(256) NOT NULL,
    password_hash VARCHAR(128),
    is_superuser BOOLEAN,
    is_deleted BOOLEAN,
    created_ts DATETIME NOT NULL,
    modified_ts TIMESTAMP NOT NULL,

    UNIQUE INDEX programmer_email_idx(email)
);
