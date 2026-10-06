import sqlite3
import csv
import os

CSV_FILE = "tdk_word_meaning_data.csv"
DB_FILE = "sozluk.db"
TABLE_NAME = "dictionary"

def create_sqlite_from_csv(csv_path, db_path):
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()

    cursor.execute(f"""
        CREATE TABLE IF NOT EXISTS {TABLE_NAME} (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            word TEXT NOT NULL,
            meaning TEXT,
            length INTEGER NOT NULL,
            iswithspace INTEGER NOT NULL
        )
    """)

    cursor.execute(f"CREATE INDEX IF NOT EXISTS idx_word ON {TABLE_NAME}(word);")
    cursor.execute(f"CREATE INDEX IF NOT EXISTS idx_length ON {TABLE_NAME}(length);")

    with open(csv_path, mode="r", encoding="utf-8-sig") as f:
        sample = f.read(2048)
        f.seek(0)
        try:
            dialect = csv.Sniffer().sniff(sample, delimiters=";,|\t,")
            delimiter = dialect.delimiter
        except Exception:
            delimiter = ","

        reader = csv.DictReader(f, delimiter=delimiter)

        rows_to_insert = []
        batch_size = 5000

        for row in reader:
            word_val = (row.get("madde") or "").strip()
            meaning_val = (row.get("anlam") or "").strip()

            if not word_val:
                continue

            # Boşluk kontrolü
            is_with_space = 1 if " " in word_val else 0

            clean_word = word_val.replace(" ", "")
            length = len(clean_word)

            rows_to_insert.append((word_val, meaning_val, length, is_with_space))

            if len(rows_to_insert) >= batch_size:
                cursor.executemany(f"""
                    INSERT INTO {TABLE_NAME} (word, meaning, length, iswithspace)
                    VALUES (?, ?, ?, ?)
                """, rows_to_insert)
                rows_to_insert.clear()

        # Kalan satırları yaz
        if rows_to_insert:
            cursor.executemany(f"""
                INSERT INTO {TABLE_NAME} (word, meaning, length, iswithspace)
                VALUES (?, ?, ?, ?)
            """, rows_to_insert)

    conn.commit()
    conn.close()
    print(f"Tamamlandı! '{db_path}' veritabanı başarıyla oluşturuldu.")

if __name__ == "__main__":
    if os.path.exists(CSV_FILE):
        create_sqlite_from_csv(CSV_FILE, DB_FILE)
    else:
        print(f"Hata: '{CSV_FILE}' dosyası bulunamadı.")