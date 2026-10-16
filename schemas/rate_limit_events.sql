-- One row per counted event (a failed login, a magic-link request) for
-- bacds::Scheduler::RateLimit. Rows older than a day are pruned
-- automatically.
CREATE TABLE rate_limit_events (
    rate_limit_event_id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    bucket              VARCHAR(32) NOT NULL,
    event_key           VARCHAR(255) NOT NULL,
    created_ts          DATETIME NOT NULL,

    INDEX rate_limit_lookup_idx(bucket, event_key, created_ts),
    INDEX rate_limit_created_idx(created_ts)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
