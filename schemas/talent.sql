CREATE TABLE talent (
    talent_id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(256) NOT NULL,
    is_deleted BOOLEAN,
    created_ts DATETIME NOT NULL,
    modified_ts TIMESTAMP NOT NULL,

    UNIQUE INDEX talent_name_idx(name)
);
