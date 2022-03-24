
CREATE TABLE styles (
    styles_id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    name varchar(256) NOT NULL,
    created_ts TIMESTAMP NOT NULL,
    modified_ts TIMESTAMP NOT NULL,

    UNIQUE INDEX styles_id_idx(name)
);
