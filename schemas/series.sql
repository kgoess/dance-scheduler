
CREATE TABLE series (
    series_id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(256),
    frequency VARCHAR(128),
    created_ts TIMESTAMP NOT NULL,
    modified_ts TIMESTAMP NOT NULL,

    INDEX series_name_idx (name)
);
