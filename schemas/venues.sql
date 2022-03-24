
CREATE TABLE venues (
    venue_id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    vkey CHAR(10) NOT NULL,
    hall_name VARCHAR(128) NOT NULL,
    address VARCHAR(256),
    city VARCHAR(64),
    zip CHAR(10),
    comment VARCHAR(32766),
    created_ts TIMESTAMP NOT NULL,
    modified_ts TIMESTAMP NOT NULL,

    UNIQUE INDEX vkey_idx (vkey)
);
