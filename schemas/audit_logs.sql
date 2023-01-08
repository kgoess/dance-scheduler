CREATE TABLE audit_logs (
    audit_log_id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    programmer_id INT NOT NULL,
    target VARCHAR(64) NOT NULL,
    target_id INT, /* NULL OK in case we use this for other things besides model updates? */
    action VARCHAR(64) NOT NULL, /* create, update */
    message VARCHAR(2048) NOT NULL,
    created_ts DATETIME NOT NULL,
    modified_ts TIMESTAMP NOT NULL,

    FOREIGN KEY (programmer_id)
        REFERENCES programmers(programmer_id)
      ON DELETE RESTRICT

) ENGINE=InnoDB DEFAULT CHARACTER SET=utf8;
