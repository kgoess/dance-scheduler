CREATE TABLE series (
    series_id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(256),
    frequency VARCHAR(128),
    short_desc varchar(2048),
    sidebar TEXT(32866),
    display_text TEXT(32866),
    series_url VARCHAR(256),
    programmer_notes TEXT(32866),
    is_deleted BOOLEAN,
    created_ts DATETIME NOT NULL,
    modified_ts TIMESTAMP NOT NULL,

    INDEX series_name_idx (name)
);
