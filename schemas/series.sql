CREATE TABLE series (
    series_id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    series_xid CHAR(24) NOT NULL,
    name VARCHAR(255),
    frequency VARCHAR(128),
    short_desc varchar(2048),
    sidebar TEXT(32866),
    display_text TEXT(32866),
    series_url VARCHAR(255),
    manager VARCHAR(255),
    programmer_notes TEXT(32866),
    is_deleted BOOLEAN NOT NULL DEFAULT 0,
    created_ts DATETIME NOT NULL,
    modified_ts TIMESTAMP NOT NULL,

    INDEX series_name_idx (name),
    UNIQUE INDEX series_xid_idx(series_xid)
) ENGINE=InnoDB DEFAULT CHARACTER SET=utf8;
