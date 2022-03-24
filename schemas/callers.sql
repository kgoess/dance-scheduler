
CREATE TABLE callers (
    caller_id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    name varchar(256) NOT NULL,
    created_ts DATETIME NOT NULL,
    modified_ts TIMESTAMP NOT NULL,

    UNIQUE INDEX caller_id_idx(name)
);
