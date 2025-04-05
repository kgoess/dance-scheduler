CREATE TABLE pages (
    page_id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    title VARCHAR(191) NOT NULL,
    url_path VARCHAR(191) NOT NULL,
    short_desc varchar(512),
    body TEXT(32866) NOT NULL,
    sidebar TEXT(32866),
    created_ts DATETIME NOT NULL,
    modified_ts TIMESTAMP NOT NULL,
    is_deleted BOOLEAN NOT NULL DEFAULT 0,
    INDEX page_title_idx (title, is_deleted),
    UNIQUE INDEX page_url_idx(url_path)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
