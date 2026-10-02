# oracle-cdc-clickhouse

## Oracle source database

Start the container:

```bash
docker compose up -d
docker compose logs -f oracle   # wait for "DATABASE IS READY TO USE!"
```

The scripts in `oracle/init/` run **only when the database is first created**. To re-run them, recreate the container:

```bash
docker compose down && docker compose up -d
```

### Connection

| User    | Password  | Service                          |
|---------|-----------|----------------------------------|
| my_user | localtest | `localhost:1521/XEPDB1`          |
| sys     | localtest | `localhost:1521/XEPDB1` (sysdba) |

### Product model (`MY_USER` schema)

```
SUPPLIER (1) ──< PRODUCT >── (1) CATEGORY ──┐
                                   ^         │ parent_category_id
                                   └─────────┘
```

- **SUPPLIER** (50 rows) – companies that supply products
- **CATEGORY** (~23 rows) – two-level hierarchy (6 parents, leaf subcategories)
- **PRODUCT** (1000 rows) – each product belongs to one leaf category and one supplier

Every table has `created_at` / `updated_at` columns; `updated_at` is kept current by triggers.
