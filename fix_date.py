import pandas as pd


INPUT_FILE = r'C:\Users\User\Desktop\Тестовое задание\dataset.csv'# путь к исходнику
OUTPUT_FILE = r'C:\Users\User\Downloads\dataset_fixed1.csv'# куда сохранить исправленный

df = pd.read_csv(INPUT_FILE, sep=';', dtype=str) # чтение файла

df['TIMESTAMP'] = pd.to_datetime(
    df['TIMESTAMP'], 
    format='%d.%m.%y %H:%M:%S,%f', 
    errors='coerce'
) # исправление timestamp
df['TIMESTAMP'] = df['TIMESTAMP'].dt.strftime('%Y-%m-%d %H:%M:%S.%f')

df['TIMESTAMP_DAY'] = pd.to_datetime(
    df['TIMESTAMP_DAY'], 
    format='%d.%m.%Y', 
    errors='coerce'
) # исправление timestamp_day
df['TIMESTAMP_DAY'] = df['TIMESTAMP_DAY'].dt.strftime('%Y-%m-%d')

df.to_csv(OUTPUT_FILE, index=False, encoding='utf-8') # сохранение
print('ready', OUTPUT_FILE)