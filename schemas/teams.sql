CREATE TABLE teams (
    team_id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(191) NOT NULL,
    team_xid CHAR(24) NOT NULL,
    parent_org_id INT, 
    contact VARCHAR (2048),
    description VARCHAR (32866),
    sidebar VARCHAR (32866),
    team_url VARCHAR(255),
    photo_url VARCHAR(255),
    is_deleted BOOLEAN NOT NULL DEFAULT 0,
    created_ts DATETIME NOT NULL,
    modified_ts TIMESTAMP NOT NULL,

    FOREIGN KEY (parent_org_id)
        REFERENCES parent_orgs(parent_org_id)
        ON DELETE RESTRICT,

    UNIQUE INDEX team_name_idx(name),
    UNIQUE INDEX team_xid_idx(team_xid)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
