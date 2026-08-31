CREATE TABLE categories (
    id        INTEGER PRIMARY KEY,
    name      TEXT    NOT NULL,
    parent_id INTEGER,
    FOREIGN KEY (parent_id)
    REFERENCES categories (id) ON UPDATE CASCADE
                               ON DELETE SET NULL
);

CREATE TABLE coupons (
    id                INTEGER PRIMARY KEY,
    code                 TEXT    NOT NULL
                                 UNIQUE,
    coupon_type          TEXT    NOT NULL
                                 CHECK (coupon_type IN ('PERCENT', 'AMOUNT') ),
    value                REAL    NOT NULL
                                 CHECK (value >= 0),
    start_at             TEXT    NOT NULL,
    end_at               TEXT    NOT NULL,
    status               TEXT    NOT NULL
                                 CHECK (status IN ('NEW', 'ISSUED', 'USED', 'EXPIRED', 'CANCELLED') ),
    issued_to_account_id INTEGER,
    FOREIGN KEY (issued_to_account_id)
    REFERENCES loyalty_accounts (id) ON UPDATE CASCADE
                                     ON DELETE SET NULL,
    CHECK (end_at >= start_at) 
);

CREATE TABLE customers (
    id         INTEGER PRIMARY KEY,
    full_name  TEXT    NOT NULL,
    phone      TEXT,
    email      TEXT,
    created_at TEXT    NOT NULL
);

CREATE TABLE loyalty_accounts (
    id             INTEGER PRIMARY KEY,
    customer_id    INTEGER NOT NULL
                           UNIQUE,
    card_no        TEXT    NOT NULL
                           UNIQUE,
    tier_id        INTEGER NOT NULL,
    points_balance INTEGER NOT NULL
                           DEFAULT 0
                           CHECK (points_balance >= 0),
    status         TEXT    NOT NULL
                           CHECK (status IN ('ACTIVE', 'BLOCKED') ),
    created_at     TEXT    NOT NULL,
    FOREIGN KEY (customer_id)
    REFERENCES customers (id) ON UPDATE CASCADE
                              ON DELETE CASCADE,
    FOREIGN KEY (tier_id)
    REFERENCES loyalty_tiers (id) ON UPDATE CASCADE
                                  ON DELETE RESTRICT
);

CREATE TABLE loyalty_point_transactions (
    id           INTEGER PRIMARY KEY,
    account_id   INTEGER NOT NULL,
    sale_id      INTEGER,
    tx_type      TEXT    NOT NULL
                         CHECK (tx_type IN ('EARN', 'SPEND', 'ADJUST', 'EXPIRE') ),
    points_delta INTEGER NOT NULL,
    tx_datetime  TEXT    NOT NULL,
    comment      TEXT,
    FOREIGN KEY (account_id)
    REFERENCES loyalty_accounts (id) ON UPDATE CASCADE
                                     ON DELETE CASCADE,
    FOREIGN KEY (sale_id)
    REFERENCES sales (id) ON UPDATE CASCADE
                          ON DELETE SET NULL
);

CREATE TABLE loyalty_rewards (
    id          INTEGER PRIMARY KEY,
    name        TEXT    NOT NULL,
    reward_type TEXT    NOT NULL
                        CHECK (reward_type IN ('COUPON', 'PRODUCT', 'ORDER_DISCOUNT') ),
    points_cost INTEGER NOT NULL
                        CHECK (points_cost >= 0),
    value       REAL,
    is_active   INTEGER NOT NULL
                        DEFAULT 1
);

CREATE TABLE loyalty_tiers (
    id         INTEGER PRIMARY KEY,
    name       TEXT    NOT NULL
                       UNIQUE,
    min_points INTEGER NOT NULL
                       CHECK (min_points >= 0),
    earn_rate  REAL    NOT NULL
                       CHECK (earn_rate >= 0) 
);

CREATE TABLE payment_methods (
    id   INTEGER PRIMARY KEY,
    code TEXT    NOT NULL
                 UNIQUE,
    name TEXT    NOT NULL
);

CREATE TABLE products (
    id          INTEGER PRIMARY KEY,
    name        TEXT    NOT NULL,
    category_id INTEGER NOT NULL,
    base_price  REAL    NOT NULL
                        CHECK (base_price >= 0),
    is_active   INTEGER NOT NULL
                        DEFAULT 1
    FOREIGN KEY (category_id)
    REFERENCES categories (id) ON UPDATE CASCADE
                               ON DELETE RESTRICT
);

CREATE TABLE sale_coupons (
    sale_id        INTEGER NOT NULL,
    coupon_id      INTEGER NOT NULL,
    applied_amount REAL    NOT NULL
                           CHECK (applied_amount >= 0),
    PRIMARY KEY (
        sale_id,
        coupon_id
    ),
    FOREIGN KEY (sale_id)
    REFERENCES sales (id) ON UPDATE CASCADE
                          ON DELETE CASCADE,
    FOREIGN KEY (coupon_id)
    REFERENCES coupons (id) ON UPDATE CASCADE
                            ON DELETE RESTRICT
);

CREATE TABLE sale_items (
    id              INTEGER PRIMARY KEY,
    sale_id         INTEGER NOT NULL,
    product_id      INTEGER NOT NULL,
    quantity        REAL    NOT NULL
                            CHECK (quantity > 0),
    unit_price      REAL    NOT NULL
                            CHECK (unit_price >= 0),
    discount_amount REAL    NOT NULL
                            DEFAULT 0
                            CHECK (discount_amount >= 0),
    FOREIGN KEY (sale_id)
    REFERENCES sales (id) ON UPDATE CASCADE
                          ON DELETE CASCADE,
    FOREIGN KEY (product_id)
    REFERENCES products (id) ON UPDATE CASCADE
                             ON DELETE RESTRICT,
    CHECK (discount_amount <= unit_price * quantity) 
);

CREATE TABLE sales (
    id                INTEGER PRIMARY KEY,
    store_id          INTEGER NOT NULL,
    customer_id       INTEGER NOT NULL,
    payment_method_id INTEGER NOT NULL,
    sale_datetime     TEXT    NOT NULL,
    receipt_no        TEXT    NOT NULL
                              UNIQUE,
    FOREIGN KEY (store_id)
    REFERENCES stores (id) ON UPDATE CASCADE
                           ON DELETE RESTRICT,
    FOREIGN KEY (customer_id)
    REFERENCES customers (id) ON UPDATE CASCADE
                              ON DELETE RESTRICT,
    FOREIGN KEY (payment_method_id)
    REFERENCES payment_methods (id) ON UPDATE CASCADE
                                    ON DELETE RESTRICT
);

CREATE TABLE stores (
    id        INTEGER PRIMARY KEY,
    name      TEXT    NOT NULL,
    city      TEXT    NOT NULL,
    address   TEXT    NOT NULL,
    opened_at TEXT,
    is_active INTEGER NOT NULL
                      DEFAULT 1
);

