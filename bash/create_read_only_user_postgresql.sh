#!/bin/bash

# Konfigurasi koneksi
HOST="127.0.0.1"
PORT="5432"
PGUSER="superuser"              # user admin (superuser) di server remote
PGPASSWORD="superuser_password" # password admin
export PGPASSWORD              # agar tidak prompt password

# User baru yang ingin dibuat
USERNAME="new_user"
PASSWORD="new_user_password"

# Buat user baru (jika belum ada)
psql -h $HOST -p $PORT -U $PGUSER -d postgres -c "DO \$\$
BEGIN
   IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = '${USERNAME}') THEN
      CREATE ROLE ${USERNAME} LOGIN PASSWORD '${PASSWORD}';
   END IF;
END
\$\$;"

# Ambil semua nama database (kecuali template dan postgres default)
DBS=$(psql -h $HOST -p $PORT -U $PGUSER -d postgres -t -c "SELECT datname FROM pg_database WHERE datistemplate = false AND datname NOT IN ('postgres');")

for DB in $DBS; do
  echo "⏳ Memberi akses ke database: $DB"

  # Beri hak connect
  psql -h $HOST -p $PORT -U $PGUSER -d "$DB" -c "GRANT CONNECT ON DATABASE \"$DB\" TO $USERNAME;"

  # Ambil semua schema (kecuali pg_catalog dan information_schema)
  SCHEMAS=$(psql -h $HOST -p $PORT -U $PGUSER -d "$DB" -t -c "SELECT schema_name FROM information_schema.schemata WHERE schema_name NOT IN ('pg_catalog', 'information_schema');")

  for SCHEMA in $SCHEMAS; do
    echo "  📁 Schema: $SCHEMA"

    # Grant usage
    psql -h $HOST -p $PORT -U $PGUSER -d "$DB" -c "GRANT USAGE ON SCHEMA \"$SCHEMA\" TO $USERNAME;"

    # Grant select pada semua tabel & view
    psql -h $HOST -p $PORT -U $PGUSER -d "$DB" -c "GRANT SELECT ON ALL TABLES IN SCHEMA \"$SCHEMA\" TO $USERNAME;"

    # Default privileges untuk future tables
    psql -h $HOST -p $PORT -U $PGUSER -d "$DB" -c "ALTER DEFAULT PRIVILEGES IN SCHEMA \"$SCHEMA\" GRANT SELECT ON TABLES TO $USERNAME;"
  done
done

echo "✅ User $USERNAME telah memiliki akses read-only ke semua database dan schema di host $HOST"