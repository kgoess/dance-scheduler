
CREATE TABLE styles (
    style_id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    name varchar(256) NOT NULL,
    created_ts DATETIME NOT NULL,
    modified_ts TIMESTAMP,

    UNIQUE INDEX styles_id_idx(name)
);
