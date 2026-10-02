-- Seed data: ~20 categories, 50 suppliers, 1000 products (deterministic).

WHENEVER SQLERROR EXIT SQL.SQLCODE
SET DEFINE OFF

CONNECT my_user/localtest@//localhost:1521/XEPDB1

-- ---------------------------------------------------------------------------
-- Categories
-- ---------------------------------------------------------------------------
DECLARE
    PROCEDURE add_parent(p_name VARCHAR2, p_desc VARCHAR2, p_children SYS.ODCIVARCHAR2LIST) IS
        v_id category.category_id%TYPE;
    BEGIN
        INSERT INTO category (name, description)
        VALUES (p_name, p_desc)
        RETURNING category_id INTO v_id;

        FOR i IN 1 .. p_children.COUNT LOOP
            INSERT INTO category (name, description, parent_category_id)
            VALUES (p_children(i), p_children(i) || ' in ' || p_name, v_id);
        END LOOP;
    END;
BEGIN
    add_parent('Electronics',     'Electronic devices and accessories',
               SYS.ODCIVARCHAR2LIST('Smartphones', 'Laptops', 'Audio', 'Accessories'));
    add_parent('Home & Kitchen',  'Products for the home',
               SYS.ODCIVARCHAR2LIST('Cookware', 'Furniture', 'Appliances'));
    add_parent('Groceries',       'Food and beverages',
               SYS.ODCIVARCHAR2LIST('Beverages', 'Snacks', 'Dairy'));
    add_parent('Health & Beauty', 'Personal care products',
               SYS.ODCIVARCHAR2LIST('Skincare', 'Vitamins', 'Pharmacy'));
    add_parent('Sports',          'Sports and outdoor equipment',
               SYS.ODCIVARCHAR2LIST('Fitness', 'Cycling'));
    add_parent('Office',          'Office supplies',
               SYS.ODCIVARCHAR2LIST('Stationery', 'Printers'));
END;
/

-- ---------------------------------------------------------------------------
-- Suppliers
-- ---------------------------------------------------------------------------
DECLARE
    v_prefix    SYS.ODCIVARCHAR2LIST := SYS.ODCIVARCHAR2LIST(
        'Alpha', 'Nova', 'Prime', 'Global', 'Blue', 'Green', 'Silver', 'Delta', 'Omega', 'Vertex');
    v_suffix    SYS.ODCIVARCHAR2LIST := SYS.ODCIVARCHAR2LIST(
        'Distribuidora', 'Trading', 'Supply', 'Industries', 'Imports');
    v_first     SYS.ODCIVARCHAR2LIST := SYS.ODCIVARCHAR2LIST(
        'Ana', 'Bruno', 'Carla', 'Diego', 'Elisa', 'Felipe', 'Gabriela', 'Hugo', 'Isabela', 'Joao');
    v_last      SYS.ODCIVARCHAR2LIST := SYS.ODCIVARCHAR2LIST(
        'Silva', 'Souza', 'Oliveira', 'Santos', 'Pereira', 'Costa', 'Lima');
    v_country   SYS.ODCIVARCHAR2LIST := SYS.ODCIVARCHAR2LIST(
        'Brazil', 'Brazil', 'Brazil', 'Argentina', 'Chile', 'USA', 'Germany', 'China');
    v_city      SYS.ODCIVARCHAR2LIST := SYS.ODCIVARCHAR2LIST(
        'Sao Paulo', 'Rio de Janeiro', 'Belo Horizonte', 'Buenos Aires', 'Santiago', 'Miami', 'Hamburg', 'Shenzhen');
    v_name      supplier.name%TYPE;
    v_idx       PLS_INTEGER;
BEGIN
    FOR i IN 1 .. 50 LOOP
        v_name := v_prefix(MOD(i - 1, v_prefix.COUNT) + 1) || ' '
               || v_suffix(MOD(TRUNC((i - 1) / v_prefix.COUNT), v_suffix.COUNT) + 1);
        v_idx  := MOD(i * 7, v_country.COUNT) + 1;

        INSERT INTO supplier (name, contact_name, email, phone, country, city, active)
        VALUES (
            v_name,
            v_first(MOD(i, v_first.COUNT) + 1) || ' ' || v_last(MOD(i * 3, v_last.COUNT) + 1),
            'contact@' || LOWER(REPLACE(v_name, ' ', '')) || '.com',
            '+55 11 9' || LPAD(TO_CHAR(10000000 + i * 137), 8, '0'),
            v_country(v_idx),
            v_city(v_idx),
            CASE WHEN MOD(i, 17) = 0 THEN 'N' ELSE 'Y' END
        );
    END LOOP;
END;
/

-- ---------------------------------------------------------------------------
-- Products (leaf categories only)
-- ---------------------------------------------------------------------------
DECLARE
    TYPE t_ids   IS TABLE OF NUMBER;
    TYPE t_names IS TABLE OF VARCHAR2(100);
    v_cat_ids    t_ids;
    v_cat_names  t_names;
    v_sup_ids    t_ids;
    v_adjective  SYS.ODCIVARCHAR2LIST := SYS.ODCIVARCHAR2LIST(
        'Premium', 'Basic', 'Pro', 'Eco', 'Ultra', 'Classic', 'Smart', 'Compact', 'Deluxe', 'Lite');
    v_cat        PLS_INTEGER;
    v_adj        VARCHAR2(30);
    v_sup_id     NUMBER;
    v_price      NUMBER(12, 2);
    v_stock      NUMBER(10);
    v_active     CHAR(1);
BEGIN
    DBMS_RANDOM.SEED(42);

    SELECT c.category_id, c.name
      BULK COLLECT INTO v_cat_ids, v_cat_names
      FROM category c
     WHERE NOT EXISTS (SELECT 1 FROM category ch WHERE ch.parent_category_id = c.category_id)
     ORDER BY c.category_id;

    SELECT supplier_id BULK COLLECT INTO v_sup_ids FROM supplier ORDER BY supplier_id;

    FOR i IN 1 .. 1000 LOOP
        v_cat := TRUNC(DBMS_RANDOM.VALUE(1, v_cat_ids.COUNT + 1));
        v_adj := v_adjective(TRUNC(DBMS_RANDOM.VALUE(1, v_adjective.COUNT + 1)));
        v_sup_id := v_sup_ids(TRUNC(DBMS_RANDOM.VALUE(1, v_sup_ids.COUNT + 1)));
        v_price  := ROUND(DBMS_RANDOM.VALUE(1, 5000), 2);
        v_stock  := TRUNC(DBMS_RANDOM.VALUE(0, 1000));
        v_active := CASE WHEN DBMS_RANDOM.VALUE < 0.05 THEN 'N' ELSE 'Y' END;

        INSERT INTO product (sku, name, description, category_id, supplier_id,
                             unit_price, stock_qty, active)
        VALUES (
            'SKU-' || LPAD(i, 6, '0'),
            v_adj || ' ' || v_cat_names(v_cat) || ' ' || TO_CHAR(i),
            v_adj || ' product from the ' || v_cat_names(v_cat) || ' category',
            v_cat_ids(v_cat),
            v_sup_id,
            v_price,
            v_stock,
            v_active
        );
    END LOOP;
END;
/

COMMIT;

EXEC DBMS_STATS.GATHER_SCHEMA_STATS('MY_USER');
