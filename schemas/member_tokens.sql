CREATE TABLE member_tokens (
    token_id           INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    token              VARCHAR(64) NOT NULL,
    civicrm_contact_id INT NOT NULL,
    created_ts         DATETIME NOT NULL,
    expires_ts         DATETIME NOT NULL,
    used_ts            DATETIME,

    UNIQUE INDEX member_token_idx(token)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
