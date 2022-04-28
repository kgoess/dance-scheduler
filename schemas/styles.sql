CREATE TABLE styles (
    style_id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(256) NOT NULL,
    is_deleted BOOLEAN,
    created_ts DATETIME NOT NULL,
    modified_ts TIMESTAMP,

    UNIQUE INDEX styles_id_idx(name)
);
