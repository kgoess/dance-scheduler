CREATE TABLE parent_orgs (
    parent_org_id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    full_name VARCHAR(256) NOT NULL,
    abbreviation VARCHAR(256) NOT NULL,
    is_deleted BOOLEAN,
    created_ts DATETIME NOT NULL,
    modified_ts TIMESTAMP NOT NULL,

    UNIQUE INDEX parent_org_id_idx(full_name)
);
