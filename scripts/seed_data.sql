INSERT INTO muffin_wallet (id, owner_name, balance, type, created_at, updated_at)
VALUES (
    '32354edf-4466-4599-8363-d14a386309dc',
    'Alice',
    1000.00,
    'CARAMEL',
    NOW(),
    NOW()
) ON CONFLICT (id) DO NOTHING;

INSERT INTO muffin_wallet (id, owner_name, balance, type, created_at, updated_at)
VALUES (
    '386b8757-f4b3-4280-8910-5b54a7959ace',
    'Bob',
    500.00,
    'PLAIN',
    NOW(),
    NOW()
) ON CONFLICT (id) DO NOTHING;